resource "tailscale_tailnet_key" "main" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags = [
    "tag:example-infra",
    "tag:example-subnetrouter",
  ]
}

resource "aws_security_group" "prod" {
  vpc_id = module.prod_vpc.vpc_id

  tags = merge(local.tags, { Name = "${local.name}-prod" })
}

resource "aws_security_group_rule" "prod_vpc_egress" {
  security_group_id = aws_security_group.prod.id

  type      = "egress"
  from_port = 0
  to_port   = 0
  protocol  = "-1"
  cidr_blocks = [
    "0.0.0.0/0",
  ]
}

resource "aws_security_group_rule" "prod_vpc_ingress" {
  security_group_id = aws_security_group.prod.id

  type      = "ingress"
  from_port = 0
  to_port   = 0
  protocol  = "-1"
  cidr_blocks = [
    # module.prod_vpc.vpc_cidr_block,
    # module.mgmt_vpc.vpc_cidr_block,
    "10.0.0.0/8",
  ]
}

resource "aws_network_interface" "primary" {
  subnet_id = module.prod_vpc.public_subnets[0]
  security_groups = [
    # module.prod_vpc.tailscale_security_group_id,
    aws_security_group.prod.id,
  ]
  tags = merge(local.tags, { Name = "${local.name}-prod-primary" })
}
resource "aws_eip" "primary" {
  tags = local.tags
}
resource "aws_eip_association" "primary" {
  network_interface_id = aws_network_interface.primary.id
  allocation_id        = aws_eip.primary.id
}

resource "aws_network_interface" "secondary" {
  subnet_id = module.prod_vpc.private_subnets[0]
  security_groups = [
    # module.prod_vpc.tailscale_security_group_id,
    aws_security_group.prod.id,
  ]
  tags = merge(local.tags, { Name = "${local.name}-prod-secondary" })

  source_dest_check = false
}

module "tailscale_aws_ec2_autoscaling" {
  source = "../internal-modules/aws-ec2-autoscaling/"

  autoscaling_group_name = local.name
  instance_type          = var.instance_type
  instance_tags          = merge(local.tags, { Name = "${local.name}-prod" })

  network_interfaces = [
    aws_network_interface.primary.id, # first NIC must be in PUBLIC subnet
    aws_network_interface.secondary.id,
  ]

  # Variables for Tailscale resources
  tailscale_hostname        = "${local.name}-prod"
  tailscale_auth_key        = tailscale_tailnet_key.main.key
  tailscale_set_preferences = var.tailscale_set_preferences
  tailscale_ssh             = true
  # tailscale_advertise_exit_node = true

  tailscale_advertise_routes = [
    # module.prod_vpc.vpc_cidr_block,
    # module.prod_vpc.private_subnets[0],
    module.mgmt_vpc.private_subnets[0],
    # var.other_vpc_cidr,
  ]

  # tailscale_advertise_connector = true
  # tailscale_advertise_aws_service_names = [
  #   "GLOBALACCELERATOR",
  # ]

  depends_on = [
    module.prod_vpc.natgw_ids, # ensure NAT gateway is available before instance provisioning - primarily for private subnets
  ]
}

