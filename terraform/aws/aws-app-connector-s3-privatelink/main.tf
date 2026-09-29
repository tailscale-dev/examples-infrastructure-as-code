# All customizable parameters in locals for easy customization.
locals {
  # common name based on the directory name
  name = "example-${basename(path.cwd)}"

  # common tags used across all resources
  aws_tags = {
    Name = local.name
  }

  # tailscale-specific arguments
  tailscale_acl_tags = [
    "tag:example-infra",
    "tag:example-appconnector",
  ]
  tailscale_set_preferences = [
    "--auto-update",
    "--ssh",
    "--advertise-connector",
  ]

  # The VPC resolver knows the interface endpoint's private DNS mapping, and the
  # endpoint ENI carries the object bytes. Both are stable, unlike the public S3
  # addresses an app connector would otherwise discover and advertise. These go in
  # the "routes" field of the app connector definition in the policy file, where
  # they are implicitly approved. See the s3_advertised_routes output.
  vpc_resolver_ip = cidrhost(local.vpc_cidr_block, 2)
  s3_advertised_routes = concat(
    ["${local.vpc_resolver_ip}/32"],
    [for eni in data.aws_network_interface.s3_endpoint : "${eni.private_ip}/32"],
  )

  # Modify these to use your own VPC. The VPC resolver address is derived from
  # the CIDR, so vpc_cidr_block must match the VPC you point this at.
  vpc_id                        = module.vpc.vpc_id
  vpc_cidr_block                = "10.0.80.0/22"
  vpc_public_subnet_cidr_blocks = ["10.0.80.0/24"]

  instance_subnet_id          = module.vpc.public_subnets[0]
  instance_security_group_ids = [aws_security_group.tailscale.id]
  instance_type               = "c7g.medium"

  # S3 bucket names are globally unique, so the directory-based name gets a suffix.
  s3_bucket_name = "${local.name}-${random_id.bucket_suffix.hex}"
  s3_object_key  = "hello.txt"
}

# Remove this to use your own VPC.
module "vpc" {
  source = "../internal-modules/aws-vpc"

  name = local.name
  tags = local.aws_tags

  cidr           = local.vpc_cidr_block
  public_subnets = local.vpc_public_subnet_cidr_blocks
}

data "aws_region" "current" {}

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

# Reads succeed only through the endpoint. A request from the internet has no
# aws:SourceVpce and gets a 403. That condition also keeps the grant non-public,
# so the policy is accepted under Block Public Access.
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

resource "aws_s3_object" "main" {
  bucket       = aws_s3_bucket.main.id
  key          = local.s3_object_key
  content      = "Reached ${local.s3_bucket_name} over AWS PrivateLink via a Tailscale app connector.\n"
  content_type = "text/plain"

  tags = merge(local.aws_tags, {
    Name = "${local.name}-${local.s3_object_key}"
  })
}

# private_dns_only_for_inbound_resolver_endpoint = false is what makes in-VPC
# resolution of the bucket domain return this endpoint's ENI address. The default
# (true) applies only to queries arriving through a Route 53 Resolver inbound
# endpoint and also requires a gateway endpoint.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Interface"

  subnet_ids          = [local.instance_subnet_id]
  security_group_ids  = [aws_security_group.s3_endpoint.id]
  private_dns_enabled = true

  dns_options {
    private_dns_only_for_inbound_resolver_endpoint = false
  }

  # Scoped to one bucket so the endpoint cannot become a private door into every
  # bucket in the account. The action list is s3:* because a client routing this
  # bucket through the endpoint sends its control-plane calls the same way, and a
  # read-only policy breaks tooling such as the AWS CLI.
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

# One ENI per subnet, and this example uses one subnet. count is used rather than
# for_each because the ENI IDs are not known at plan time.
data "aws_network_interface" "s3_endpoint" {
  count = 1

  id = tolist(aws_vpc_endpoint.s3.network_interface_ids)[count.index]
}

# Only this exact bucket name resolves at the VPC resolver. Sibling buckets do
# not match, resolve publicly, and never involve the connector.
resource "tailscale_dns_split_nameservers" "main" {
  domain      = aws_s3_bucket.main.bucket_regional_domain_name
  nameservers = [local.vpc_resolver_ip]
}

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

  subnet_id              = local.instance_subnet_id
  vpc_security_group_ids = local.instance_security_group_ids

  # Variables for Tailscale resources
  tailscale_hostname        = local.name
  tailscale_auth_key        = tailscale_tailnet_key.main.key
  tailscale_set_preferences = local.tailscale_set_preferences

  depends_on = [
    module.vpc.nat_ids, # remove if using your own VPC otherwise ensure provisioned NAT gateway is available
  ]
}

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
