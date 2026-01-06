locals {
  name = "example-${basename(path.cwd)}"

  aws_tags = {
    Name = local.name
  }

  tailscale_acl_tags = [
    "tag:example-infra",
  ]
  tailscale_set_preferences = [
    "--auto-update",
    "--ssh",
  ]

  # Modify these to use your own VPC
  vpc_cidr_block     = module.vpc.vpc_cidr_block
  vpc_id             = module.vpc.vpc_id
  subnet_id          = module.vpc.private_subnets[0]
  security_group_ids = [aws_security_group.tailscale.id]
  instance_type      = "c7g.medium"
  vpc_endpoint_route_table_ids = flatten([
    module.vpc.public_route_table_ids,
    module.vpc.private_route_table_ids,
  ])
}

# Remove this to use your own VPC.
module "vpc" {
  source = "../internal-modules/aws-vpc"

  name = local.name
  tags = local.aws_tags
}

resource "aws_vpc_endpoint" "recorder" {
  vpc_id          = local.vpc_id
  service_name    = "com.amazonaws.${aws_s3_bucket.recorder.region}.s3"
  route_table_ids = local.vpc_endpoint_route_table_ids
  tags            = local.aws_tags
}

resource "aws_s3_bucket" "recorder" {
  bucket_prefix = substr(local.name, 0, 37)
  tags          = local.aws_tags

  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "recorder" {
  bucket = aws_s3_bucket.recorder.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "recorder" {
  bucket = aws_s3_bucket.recorder.id
  policy = <<-EOT
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "Allow-access-from-specific-VPCE",
        "Effect": "Deny",
        "Principal": "*",
        "Action": [
          "s3:PutObject",
          "s3:GetObject"
        ],
        "Resource": [
          "${aws_s3_bucket.recorder.arn}",
          "${aws_s3_bucket.recorder.arn}/*"
        ],
        "Condition": {
          "StringNotEquals": {
            "aws:sourceVpce": "${aws_vpc_endpoint.recorder.id}"
          }
        }
      }
    ]
  }
  EOT
}

resource "aws_iam_policy" "recorder" {
  tags   = local.aws_tags
  policy = <<-EOT
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:PutObject",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        "Resource": [
          "${aws_s3_bucket.recorder.arn}",
          "${aws_s3_bucket.recorder.arn}/*"
        ]
      }
    ]
  }
  EOT
}

resource "aws_iam_user" "recorder" {
  name = local.name
  tags = local.aws_tags
}

resource "aws_iam_policy_attachment" "recorder" {
  name       = local.name
  policy_arn = aws_iam_policy.recorder.arn
  users      = [aws_iam_user.recorder.name]
}

resource "aws_iam_access_key" "recorder" {
  user = aws_iam_user.recorder.name
}

resource "tailscale_tailnet_key" "recorder" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags = [
    "tag:example-sessionrecorder",
  ]
}

resource "tailscale_tailnet_key" "main" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags                = local.tailscale_acl_tags
}

module "tailscale_aws_ec2_autoscaling" {
  source = "../internal-modules/aws-ec2-autoscaling/"

  autoscaling_group_name = local.name
  instance_type          = local.instance_type
  instance_tags          = local.aws_tags

  subnet_id          = local.subnet_id
  security_group_ids = local.security_group_ids

  # Variables for Tailscale resources
  tailscale_hostname        = local.name
  tailscale_auth_key        = tailscale_tailnet_key.main.key
  tailscale_set_preferences = local.tailscale_set_preferences

  #
  # Set up Tailscale Session Recorder (tsrecorder)
  #
  additional_after_scripts = [
    templatefile(
      "${path.module}/scripts/tsrecorder_docker.tftpl",
      {
        tailscale_recorder_auth_key = tailscale_tailnet_key.recorder.key,
        aws_access_key              = aws_iam_access_key.recorder.id,
        aws_secret_access_key       = aws_iam_access_key.recorder.secret,
        bucket_name                 = aws_s3_bucket.recorder.bucket,
        bucket_region               = aws_s3_bucket.recorder.region,
      }
    )
  ]

  depends_on = [
    module.vpc.nat_ids, # remove if using your own VPC otherwise ensure provisioned NAT gateway is available
  ]
}

resource "aws_security_group" "tailscale" {
  vpc_id = local.vpc_id
  name   = local.name
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
