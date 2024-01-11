locals {
  name = var.name != "" ? var.name : "example-${basename(path.cwd)}"

  tags = length(var.tags) > 0 ? var.tags : {
    Name = local.name
  }
}

module "vpc" {
  source = "../internal-modules/aws-vpc"

  name = local.name
  tags = local.tags

  cidr = var.vpc_cidr_block

  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
}

resource "aws_vpc_endpoint" "recorder" {
  vpc_id       = module.vpc.vpc_id
  service_name = "com.amazonaws.${aws_s3_bucket.recorder.region}.s3"
  route_table_ids = flatten([
    module.vpc.public_route_table_ids,
    module.vpc.private_route_table_ids,
  ])
  tags = local.tags
}

resource "aws_s3_bucket" "recorder" {
  bucket_prefix = substr(local.name, 0, 37)
  tags          = local.tags

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
  tags   = local.tags
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
  tags = local.tags
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
  tags                = var.tailscale_device_tags_recorder
}

resource "tailscale_tailnet_key" "main" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags                = var.tailscale_device_tags
}

resource "aws_network_interface" "primary" {
  subnet_id       = module.vpc.public_subnets[0]
  security_groups = [module.vpc.tailscale_security_group_id]
  tags            = local.tags
}
resource "aws_eip" "primary" {
  tags = local.tags
}
resource "aws_eip_association" "primary" {
  network_interface_id = aws_network_interface.primary.id
  allocation_id        = aws_eip.primary.id
}

module "tailscale_aws_ec2_autoscaling" {
  source = "../internal-modules/aws-ec2-autoscaling/"

  autoscaling_group_name = local.name

  network_interfaces = [aws_network_interface.primary.id]

  instance_type = var.instance_type
  instance_tags = local.tags

  # Variables for Tailscale resources
  tailscale_hostname        = local.name
  tailscale_auth_key        = tailscale_tailnet_key.main.key
  tailscale_set_preferences = var.tailscale_set_preferences
  tailscale_ssh             = true

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
    module.vpc.natgw_ids, # for private subnets - ensure NAT gateway is available before instance provisioning
  ]
}
