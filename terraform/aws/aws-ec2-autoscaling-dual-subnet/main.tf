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
  tags            = merge(local.tags, { Name = "${local.name}-primary" })
}
resource "aws_eip" "primary" {
  tags = local.tags
}
resource "aws_eip_association" "primary" {
  network_interface_id = aws_network_interface.primary.id
  allocation_id        = aws_eip.primary.id
}

resource "aws_network_interface" "secondary" {
  subnet_id       = module.vpc.private_subnets[0]
  security_groups = [module.vpc.tailscale_security_group_id]
  tags            = merge(local.tags, { Name = "${local.name}-secondary" })

  source_dest_check = false
}

module "tailscale_aws_ec2_autoscaling" {
  source = "../internal-modules/aws-ec2-autoscaling/"

  autoscaling_group_name = local.name
  instance_type          = var.instance_type
  instance_tags          = local.tags

  network_interfaces = [
    aws_network_interface.primary.id, # first NIC must be in PUBLIC subnet
    aws_network_interface.secondary.id,
  ]

  # Variables for Tailscale resources
  tailscale_hostname            = local.name
  tailscale_auth_key            = tailscale_tailnet_key.main.key
  tailscale_set_preferences     = var.tailscale_set_preferences
  tailscale_ssh                 = true
  tailscale_advertise_exit_node = false

  tailscale_advertise_routes = [
    module.vpc.vpc_cidr_block,
  ]

  tailscale_advertise_connector = true
  # tailscale_advertise_aws_service_names = [
  #   "EC2",
  # ]

  instance_profile_name = aws_iam_instance_profile.routes.name
  additional_after_scripts = [
    local.script_routes_restore,
    local.script_routes_persist,
  ]

  # tailscale_advertise_okta_cell_names = [
  #   "emea_cell_2",
  # ]
  # tailscale_advertise_github_service_names = [
  #   "api",
  #   "packages",
  #   "website",
  # ]

  depends_on = [
    module.vpc.natgw_ids, # ensure NAT gateway is available before instance provisioning - primarily for private subnets
  ]
}

