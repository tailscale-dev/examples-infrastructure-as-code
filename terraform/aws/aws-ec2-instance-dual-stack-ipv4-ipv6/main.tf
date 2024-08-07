locals {
  name = "example-${basename(path.cwd)}"

  tags = {
    Name = local.name
  }
}

module "vpc" {
  source = "../internal-modules/aws-vpc"

  name = local.name
  tags = local.tags

  cidr = "10.0.80.0/22"

  public_subnets  = ["10.0.80.0/24"]
  private_subnets = ["10.0.81.0/24"]

  enable_ipv6 = true
}

resource "tailscale_tailnet_key" "main" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags = [
    "tag:example-infra",
    "tag:example-exitnode",
    "tag:example-subnetrouter",
    "tag:example-appconnector",
  ]
}

module "tailscale_aws_ec2" {
  source = "../internal-modules/aws-ec2-instance"

  instance_type = "t4g.micro"
  instance_tags = local.tags

  subnet_id = module.vpc.private_subnets[0]
  vpc_security_group_ids = [
    module.vpc.tailscale_security_group_id,
  ]
  ipv6_address_count = 1

  # Variables for Tailscale resources
  tailscale_hostname = local.name
  tailscale_auth_key = tailscale_tailnet_key.main.key
  tailscale_set_preferences = [
    "--auto-update",
  ]
  tailscale_ssh                 = true
  tailscale_advertise_exit_node = true

  tailscale_advertise_routes = concat(
    [module.vpc.vpc_cidr_block],
    [module.vpc.vpc_ipv6_cidr_block],
  )

  tailscale_advertise_connector = true

  depends_on = [
    module.vpc.natgw_ids, # ensure NAT gateway is available before instance provisioning - primarily for private subnets
  ]
}
