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
  instance_type          = "t4g.micro"
  instance_tags          = local.tags

  network_interfaces = [
    aws_network_interface.primary.id, # first NIC must be in PUBLIC subnet
    aws_network_interface.secondary.id,
  ]

  # Variables for Tailscale resources
  tailscale_hostname = local.name
  tailscale_auth_key = tailscale_tailnet_key.main.key
  tailscale_set_preferences = [
    "--auto-update",
    "--ssh",
    "--advertise-connector",
    "--advertise-exit-node",
    "--advertise-routes=${join(",", [module.vpc.vpc_cidr_block])}",
  ]

  depends_on = [
    module.vpc.natgw_ids, # ensure NAT gateway is available before instance provisioning - primarily for private subnets
  ]
}
