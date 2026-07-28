locals {
  name = "example-${basename(path.cwd)}"

  aws_tags = {
    Name = local.name
  }

  tailscale_acl_tags = [
    "tag:example-infra",
    "tag:example-appconnector",
  ]

  # The connector plays two roles at once. --advertise-connector registers it as
  # an app connector for the bucket domain named in the policy file, which is the
  # handle you write access rules against. --advertise-routes pins the two
  # addresses that domain actually needs, so the advertised route set is a fixed
  # pair rather than whatever S3's public endpoint happens to resolve to.
  tailscale_set_preferences = [
    "--auto-update",
    "--ssh",
    "--advertise-connector",
    "--advertise-routes=${join(",", local.s3_advertised_routes)}",
  ]

  # The two routes that make one bucket private. The first is the VPC's own
  # Route 53 Resolver (VPC base + 2), the only resolver that knows the interface
  # endpoint's private DNS mapping. The second is the endpoint ENI itself, which
  # carries the object bytes. Both are stable for the life of the VPC.
  s3_advertised_routes = concat(
    ["${local.vpc_resolver_ip}/32"],
    [for eni in data.aws_network_interface.s3_endpoint : "${eni.private_ip}/32"],
  )
  vpc_resolver_ip = cidrhost(local.vpc_cidr_block, 2)

  # Modify these to use your own VPC. enable_dns_support and enable_dns_hostnames
  # must both be on, or the interface endpoint's private DNS override does
  # nothing. The community VPC module defaults both to true.
  vpc_cidr_block     = "10.0.80.0/22"
  vpc_id             = module.vpc.vpc_id
  subnet_id          = module.vpc.public_subnets[0]
  security_group_ids = [aws_security_group.tailscale.id]
  instance_type      = "c7g.medium"

  # The bucket that goes private. S3 bucket names are globally unique, so the
  # directory-based name gets a random suffix.
  s3_bucket_name = "${local.name}-${random_id.bucket_suffix.hex}"
}

# Remove this to use your own VPC.
module "vpc" {
  source = "../internal-modules/aws-vpc"

  name = local.name
  tags = local.aws_tags

  cidr = local.vpc_cidr_block
}

data "aws_region" "current" {}

#
# The bucket to be reached privately
#

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "main" {
  bucket        = local.s3_bucket_name
  force_destroy = true

  tags = merge(local.aws_tags, {
    Name = local.s3_bucket_name
  })
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Reads succeed only when the request arrived through the interface endpoint. A
# request from the open internet has no aws:SourceVpce and is denied, so this is
# what proves the traffic took the private path. An aws:SourceVpce condition is
# not a public grant, so the policy is accepted under Block Public Access.
resource "aws_s3_bucket_policy" "main" {
  bucket     = aws_s3_bucket.main.id
  depends_on = [aws_s3_bucket_public_access_block.main]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowThroughS3PrivateLink"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.main.arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceVpce" = aws_vpc_endpoint.s3.id
          }
        }
      },
    ]
  })
}

resource "aws_s3_object" "hello" {
  bucket       = aws_s3_bucket.main.id
  key          = "hello.txt"
  content      = "Reached ${local.s3_bucket_name} over AWS PrivateLink via a Tailscale app connector.\n"
  content_type = "text/plain"
}

#
# The private path into S3
#

# private_dns_enabled with private_dns_only_for_inbound_resolver_endpoint set to
# false is what makes in-VPC resolution of the S3 regional domain return this
# endpoint's ENI address instead of a public one. The default (true) applies only
# to queries arriving through a Route 53 Resolver inbound endpoint and also
# requires a gateway endpoint, neither of which is in play here.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Interface"

  subnet_ids          = [local.subnet_id]
  security_group_ids  = [aws_security_group.s3_endpoint.id]
  private_dns_enabled = true

  dns_options {
    private_dns_only_for_inbound_resolver_endpoint = false
  }

  # Scope the endpoint to this one bucket, so it cannot become a general private
  # door into every bucket in the account. The action list is s3:* rather than
  # just GetObject because a client whose split DNS routes this bucket through
  # the endpoint sends its control-plane calls the same way, and a read-only
  # endpoint policy makes tooling such as the AWS CLI fail against the bucket.
  # The bucket ARN in Resource is what keeps the scope narrow.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "OnlyThisBucket"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.main.arn, "${aws_s3_bucket.main.arn}/*"]
      },
    ]
  })

  tags = merge(local.aws_tags, {
    Name = "${local.name}-s3"
  })
}

# The endpoint's ENI addresses, read back so they can be advertised as routes.
# One ENI per subnet, and this example uses one subnet. count is used rather than
# for_each because the instance count is known at plan time while the ENI IDs are
# not, and a for_each over unknown IDs cannot be planned.
data "aws_network_interface" "s3_endpoint" {
  count = 1

  id = tolist(aws_vpc_endpoint.s3.network_interface_ids)[count.index]
}

# Tell the tailnet that this one bucket name resolves at the VPC resolver. Only
# this exact FQDN is sent there, so sibling buckets keep resolving publicly and
# never touch the connector. This is the piece that scopes "private" to a single
# bucket rather than to all of S3.
resource "tailscale_dns_split_nameservers" "s3" {
  domain      = aws_s3_bucket.main.bucket_regional_domain_name
  nameservers = [local.vpc_resolver_ip]
}

#
# The app connector
#

resource "tailscale_tailnet_key" "main" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags                = local.tailscale_acl_tags
}

module "tailscale_aws_ec2" {
  source = "../internal-modules/aws-ec2-instance"

  instance_type = local.instance_type
  instance_tags = local.aws_tags

  subnet_id              = local.subnet_id
  vpc_security_group_ids = local.security_group_ids

  # Variables for Tailscale resources
  tailscale_hostname        = local.name
  tailscale_auth_key        = tailscale_tailnet_key.main.key
  tailscale_set_preferences = local.tailscale_set_preferences

  depends_on = [
    module.vpc.nat_ids, # remove if using your own VPC otherwise ensure provisioned NAT gateway is available
  ]
}

#
# Security groups
#

resource "aws_security_group" "tailscale" {
  vpc_id = local.vpc_id
  name   = local.name

  tags = local.aws_tags
}

resource "aws_security_group_rule" "tailscale_ingress" {
  security_group_id = aws_security_group.tailscale.id
  type              = "ingress"
  from_port         = 41641
  to_port           = 41641
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}

resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.tailscale.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}

resource "aws_security_group_rule" "internal_vpc_ingress_ipv4" {
  security_group_id = aws_security_group.tailscale.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [local.vpc_cidr_block]
}

resource "aws_security_group" "s3_endpoint" {
  vpc_id      = local.vpc_id
  name        = "${local.name}-s3"
  description = "S3 interface VPC endpoint. HTTPS from within the VPC only."

  tags = merge(local.aws_tags, {
    Name = "${local.name}-s3"
  })
}

resource "aws_security_group_rule" "s3_endpoint_ingress" {
  security_group_id = aws_security_group.s3_endpoint.id
  description       = "HTTPS from within the VPC"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [local.vpc_cidr_block]
}
