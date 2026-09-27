locals {
  name = "example-${basename(path.cwd)}"

  aws_tags = {
    Name = local.name
  }

  tailscale_acl_tags = [
    "tag:example-infra",
  ]

  # Modify these to use your own VPC
  vpc_cidr_block     = module.vpc.vpc_cidr_block
  vpc_id             = module.vpc.vpc_id
  subnet_id          = module.vpc.public_subnets[0]
  security_group_ids = [aws_security_group.tailscale.id]
  instance_type      = "t3.medium"

  # Use the provided auth key if set, otherwise use the one created below.
  tailscale_auth_key = coalesce(var.tailscale_auth_key, try(tailscale_tailnet_key.main[0].key, null))

  windows_admin_password_ssm_parameter_name = "/${local.name}/windows-admin-password"
  tailscale_auth_key_ssm_parameter_name     = "/${local.name}/tailscale-auth-key"
}

# Remove this to use your own VPC.
module "vpc" {
  source = "../internal-modules/aws-vpc"

  name = local.name
  tags = local.aws_tags
}

resource "tailscale_tailnet_key" "main" {
  count = var.tailscale_auth_key == null ? 1 : 0

  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags                = local.tailscale_acl_tags
}

# The default AWS-managed KMS key used to encrypt SecureString parameters.
data "aws_kms_alias" "ssm" {
  name = "alias/aws/ssm"
}

resource "aws_ssm_parameter" "windows_admin_password" {
  name  = local.windows_admin_password_ssm_parameter_name
  type  = "SecureString"
  value = var.windows_admin_password
}

resource "aws_ssm_parameter" "tailscale_auth_key" {
  name  = local.tailscale_auth_key_ssm_parameter_name
  type  = "SecureString"
  value = local.tailscale_auth_key
}

resource "aws_iam_role" "windows_instance" {
  name = local.name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { Service = "ec2.amazonaws.com" }
      },
    ]
  })
}

resource "aws_iam_role_policy" "windows_instance_ssm" {
  name = "read-windows-admin-password"
  role = aws_iam_role.windows_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "ssm:GetParameter"
        Resource = [
          aws_ssm_parameter.windows_admin_password.arn,
          aws_ssm_parameter.tailscale_auth_key.arn,
        ]
      },
      {
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = data.aws_kms_alias.ssm.target_key_arn
      },
    ]
  })
}

resource "aws_iam_instance_profile" "windows_instance" {
  name = local.name
  role = aws_iam_role.windows_instance.name
}

module "tailscale_aws_ec2_windows" {
  source = "../internal-modules/aws-ec2-instance-windows-server"

  instance_type = local.instance_type
  instance_tags = local.aws_tags

  subnet_id              = local.subnet_id
  vpc_security_group_ids = local.security_group_ids

  instance_profile_name = aws_iam_instance_profile.windows_instance.name

  # Variables for Tailscale resources
  tailscale_hostname = local.name

  depends_on = [
    aws_ssm_parameter.tailscale_auth_key,
    aws_ssm_parameter.windows_admin_password,
    aws_iam_role_policy.windows_instance_ssm,
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
