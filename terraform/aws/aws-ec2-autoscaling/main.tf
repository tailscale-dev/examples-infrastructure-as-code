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
  instance_type          = "t4g.micro"
  instance_tags          = local.tags

  network_interfaces = [aws_network_interface.primary.id]

  # Variables for Tailscale resources
  tailscale_auth_key = tailscale_tailnet_key.main.key
  tailscale_hostname = local.name
  tailscale_set_preferences = [
    "--auto-update",
  ]
  tailscale_ssh                 = true
  tailscale_advertise_exit_node = true

  tailscale_advertise_routes = [
    module.vpc.vpc_cidr_block,
  ]

  tailscale_advertise_connector = true
  # tailscale_advertise_aws_service_names = [
  #   "GLOBALACCELERATOR",
  # ]

  depends_on = [
    module.vpc.natgw_ids, # ensure NAT gateway is available before instance provisioning - primarily for private subnets
  ]
}
