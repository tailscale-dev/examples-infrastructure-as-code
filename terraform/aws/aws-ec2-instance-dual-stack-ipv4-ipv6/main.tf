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

  enable_ipv6 = true
}

resource "tailscale_tailnet_key" "main" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags                = var.tailscale_device_tags
}

module "tailscale_aws_ec2" {
  source = "../internal-modules/aws-ec2-instance"

  subnet_id = module.vpc.public_subnets[0]

  vpc_security_group_ids = [
    module.vpc.tailscale_security_group_id,
  ]

  instance_type = var.instance_type
  instance_tags = local.tags

  # Variables for Tailscale resources
  tailscale_hostname            = local.name
  tailscale_auth_key            = tailscale_tailnet_key.main.key
  tailscale_set_preferences     = var.tailscale_set_preferences
  tailscale_ssh                 = true
  tailscale_advertise_exit_node = true

  tailscale_advertise_routes = concat(
    [module.vpc.vpc_cidr_block],
    [module.vpc.vpc_ipv6_cidr_block],
  )

  tailscale_advertise_connector = true
  # tailscale_advertise_github_service_names = [
  #   "api",
  #   "packages",
  #   "website",
  # ]

  depends_on = [
    module.vpc.natgw_ids, # ensure NAT gateway is available before instance provisioning - primarily for private subnets
  ]
}
