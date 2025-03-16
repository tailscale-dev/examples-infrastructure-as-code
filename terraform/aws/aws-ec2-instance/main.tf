locals {
  name = "site-to-tailnet"

  aws_tags = {
    Name = local.name
  }

  #   tailscale_acl_tags = [
  #     "tag:example-infra",
  #     "tag:example-subnetrouter",
  #     "tag:example-appconnector",
  #     "tag:example-exitnode",
  #   ]
  #   tailscale_set_preferences = [
  #     "--auto-update",
  #     "--ssh",
  #     "--advertise-exit-node",
  #     # "--advertise-connector",
  #     # "--advertise-routes=${join(",", [
  #     #   local.vpc_cidr_block,
  #     # ])}",
  #   ]

  // Modify these to use your own VPC
  vpc_cidr_block     = module.vpc.vpc_cidr_block
  vpc_id             = module.vpc.vpc_id
  subnet_id          = module.vpc.public_subnets[0]
  security_group_ids = [aws_security_group.tailscale.id]
  instance_type      = "c7g.medium"
}

// Remove this to use your own VPC.
module "vpc" {
  source = "../internal-modules/aws-vpc"

  name = local.name
  tags = local.aws_tags

  cidr = "10.0.80.0/22"

  public_subnets  = ["10.0.80.0/24"]
  private_subnets = ["10.0.81.0/24"]
}

resource "tailscale_tailnet_key" "main" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags = [
    "tag:example-infra",
  ]
}

resource "tailscale_tailnet_key" "subnetrouter" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags = [
    "tag:example-infra",
    "tag:example-subnetrouter",
  ]
}

resource "aws_security_group" "tailscale" {
  vpc_id = local.vpc_id
  name   = local.name
}

resource "aws_security_group_rule" "all_internal_udp" {
  security_group_id = aws_security_group.tailscale.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "udp"
  cidr_blocks = [
    module.vpc.vpc_cidr_block,
    "0.0.0.0/0",
  ]
  ipv6_cidr_blocks = ["::/0"]
}

resource "aws_security_group_rule" "all_internal_tcp" {
  security_group_id = aws_security_group.tailscale.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "tcp"
  cidr_blocks = [
    module.vpc.vpc_cidr_block,
    "0.0.0.0/0",
  ]
  ipv6_cidr_blocks = ["::/0"]
}

resource "aws_security_group_rule" "ssh" {
  security_group_id = aws_security_group.tailscale.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
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

module "site-to-tailnet-device" {
  source = "../internal-modules/aws-ec2-instance"

  instance_type = local.instance_type
  instance_tags = merge(local.aws_tags, {
    Name = "${local.name}-device"
  })

  subnet_id              = local.subnet_id
  vpc_security_group_ids = local.security_group_ids

  # Variables for Tailscale resources
  tailscale_hostname = "${local.name}-device"
  tailscale_auth_key = tailscale_tailnet_key.main.key
  tailscale_set_preferences = [
    "--auto-update",
    "--ssh",
    "--accept-routes",
  ]

  depends_on = [
    module.vpc.nat_ids, # remove if using your own VPC otherwise ensure provisioned NAT gateway is available
  ]
}

output "site-to-tailnet-device-addresses" {
  value = [
    module.site-to-tailnet-device.instance_public_ip,
    module.site-to-tailnet-device.instance_private_ip,
  ]
}

resource "aws_route" "tailnet_public" {
  count = length(module.vpc.public_route_table_ids)

  route_table_id         = module.vpc.public_route_table_ids[count.index]
  destination_cidr_block = "100.64.0.0/10"
  network_interface_id   = module.site-to-tailnet-subnetrouter.eni_id
}

resource "aws_route" "tailnet_private" {
  count = length(module.vpc.private_route_table_ids)

  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "100.64.0.0/10"
  network_interface_id   = module.site-to-tailnet-subnetrouter.eni_id
}

module "site-to-tailnet-subnetrouter" {
  source = "../internal-modules/aws-ec2-instance"

  instance_type = local.instance_type
  instance_tags = merge(local.aws_tags, {
    Name = "${local.name}-subnetrouter"
  })

  subnet_id              = local.subnet_id
  vpc_security_group_ids = local.security_group_ids

  # Variables for Tailscale resources
  tailscale_hostname = "${local.name}-subnetrouter"
  tailscale_auth_key = tailscale_tailnet_key.subnetrouter.key
  tailscale_set_preferences = [
    "--auto-update",
    "--ssh",
    "--advertise-routes=${join(",", [
      local.vpc_cidr_block,
      "100.64.0.0/10",
    ])}",
    # "--snat-subnet-routes=false",
    # "--stateful-filtering=false",
  ]

  additional_after_scripts = [
    templatefile("${path.module}/../../internal-modules/tailscale-install-scripts/scripts/additional-scripts/ip-forwarding.tftpl", {}),
  ]

  depends_on = [
    module.vpc.nat_ids, # remove if using your own VPC otherwise ensure provisioned NAT gateway is available
  ]
}

output "site-to-tailnet-subnetrouter-addresses" {
  value = [
    module.site-to-tailnet-subnetrouter.instance_public_ip,
    module.site-to-tailnet-subnetrouter.instance_private_ip,
  ]
}

resource "aws_key_pair" "main" { # TODO: REMOVE
    key_name   = "${local.name}"
    public_key = var.public_key
}

module "site-to-tailnet-device-non-tailscale" {
  source = "../internal-modules/aws-ec2-instance"

  instance_type = local.instance_type
  instance_tags = merge(local.aws_tags, {
    Name = "${local.name}-device-non-tailscale"
  })

  subnet_id              = local.subnet_id
  vpc_security_group_ids = local.security_group_ids

  instance_key_name = aws_key_pair.main.key_name  # TODO: REMOVE

  # Variables for Tailscale resources
  tailscale_hostname = "${local.name}-device-non-tailscale"
  tailscale_auth_key = tailscale_tailnet_key.main.key
  tailscale_set_preferences = [
    "--auto-update",
    "--ssh",
  ]
  additional_after_scripts = [
    "sudo tailscale down",
    "sudo tailscale logout",
    # "snap start amazon-ssm-agent",
  ]

  depends_on = [
    module.vpc.nat_ids, # remove if using your own VPC otherwise ensure provisioned NAT gateway is available
  ]
}

output "device-non-tailscale-instance-id" {
  value = module.site-to-tailnet-device-non-tailscale.instance_id
}

output "site-to-tailnet-device-non-tailscale-addresses" {
  value = [
    module.site-to-tailnet-device-non-tailscale.instance_public_ip,
    module.site-to-tailnet-device-non-tailscale.instance_private_ip,
  ]
}

#
# SSM - FIX, aws ssm cli reports `An error occurred (TargetNotConnected) when calling the StartSession operation: i-... is not connected.`
#
# resource "aws_iam_role" "ssm" {
#   name = "${local.name}-ssm"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Sid    = ""
#       Principal = {
#         Service = "ec2.amazonaws.com"
#       }
#   }] })
# }

# resource "aws_iam_instance_profile" "ssm" {
#   name = "${local.name}-ssm"
#   role = aws_iam_role.ssm.name
# }

# data "aws_iam_policy_document" "ssm" {
#   statement {
#     sid    = "SessionManager"
#     effect = "Allow"
#     actions = [
#       "ssmmessages:CreateDataChannel",
#       "ssmmessages:OpenDataChannel",
#       "ssmmessages:CreateControlChannel",
#       "ssmmessages:OpenControlChannel",
#       "ssm:UpdateInstanceInformation",
#     ]
#     resources = [
#       module.site-to-tailnet-device-non-tailscale.instance_arn,
#     ]
#   }
# }

# resource "aws_iam_policy" "ssm" {
#   name   = "${local.name}-ssm"
#   policy = data.aws_iam_policy_document.ssm.json
# }

# resource "aws_iam_role_policy_attachment" "ssm" {
#   role       = aws_iam_role.ssm.name
#   policy_arn = aws_iam_policy.ssm.arn
# }
