resource "tailscale_tailnet_key" "other" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags = [
    "tag:example-infra",
  ]
}

resource "aws_security_group" "mgmt_instance" {
  vpc_id = module.mgmt_vpc.vpc_id

  tags = merge(local.tags, { Name = "${local.name}-mgmt-instance" })
}

resource "aws_security_group_rule" "mgmt_instance_vpc_egress" {
  security_group_id = aws_security_group.mgmt_instance.id

  type      = "egress"
  from_port = 0
  to_port   = 0
  protocol  = "-1"
  cidr_blocks = [
    "0.0.0.0/0",
  ]
}

resource "aws_security_group_rule" "mgmt_instance_vpc_ingress" {
  security_group_id = aws_security_group.mgmt_instance.id

  type      = "ingress"
  from_port = 0
  to_port   = 0
  protocol  = "-1"
  cidr_blocks = [
    # module.mgmt_vpc.vpc_cidr_block,
    "10.0.0.0/8",
    "192.168.0.0/20",
  ]
}

module "mgmt_instance" {
  source = "../internal-modules/aws-ec2-instance"

  subnet_id = module.mgmt_vpc.private_subnets[0]

  vpc_security_group_ids = [
    # module.mgmt_vpc.tailscale_security_group_id,
    aws_security_group.mgmt_instance.id,
  ]

  instance_type = var.instance_type
  instance_tags = merge(local.tags, { Name = "${local.name}-mgmt-instance-private" })

  # Variables for Tailscale resources
  tailscale_hostname        = "${local.name}-mgmt-instance-private"
  tailscale_auth_key        = tailscale_tailnet_key.other.key
  tailscale_set_preferences = var.tailscale_set_preferences
  tailscale_ssh             = true
  #   tailscale_advertise_exit_node = true

  #   tailscale_advertise_routes = [
  #     module.vpc.vpc_cidr_block,
  #   ]

  tailscale_advertise_connector = false
  # tailscale_advertise_aws_service_names = [
  #   "GLOBALACCELERATOR",
  # ]

  depends_on = [
    module.mgmt_vpc.natgw_ids, # ensure NAT gateway is available before instance provisioning - primarily for private subnets
  ]
}
