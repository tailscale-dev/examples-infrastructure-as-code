locals {
  name = "cameron-tgw-test"

  tags = length(var.tags) > 0 ? var.tags : {
    Name = local.name
  }

  region = "us-west-2"

  staging_name = "${local.name}-staging"
  mgmt_name    = "${local.name}-mangement"
  prod_name    = "${local.name}-prod"

  # prod_vpc_cidr    = "10.0.0.0/16"
  # staging_vpc_cidr = "10.10.0.0/16"
  # qa_vpc_cidr      = "10.20.0.0/16"
  # mgmt_vpc_cidr    = "10.30.0.0/16"
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  staging_tags = {
    environment = local.staging_name
  }
  prod_tags = {
    environment = local.prod_name
  }

}

# resource "tailscale_tailnet_key" "main" {
#   ephemeral           = true
#   preauthorized       = true
#   reusable            = true
#   recreate_if_invalid = "always"
#   tags                = var.tailscale_device_tags
# }

# resource "aws_network_interface" "primary" {
#   subnet_id       = module.vpc.public_subnets[0]
#   security_groups = [module.vpc.tailscale_security_group_id]
#   tags            = merge(local.tags, { Name = "${local.name}-primary" })
# }
# resource "aws_eip" "primary" {
#   tags = local.tags
# }
# resource "aws_eip_association" "primary" {
#   network_interface_id = aws_network_interface.primary.id
#   allocation_id        = aws_eip.primary.id
# }

# resource "aws_network_interface" "secondary" {
#   subnet_id       = module.vpc.private_subnets[0]
#   security_groups = [module.vpc.tailscale_security_group_id]
#   tags            = merge(local.tags, { Name = "${local.name}-secondary" })

#   source_dest_check = false
# }

# module "tailscale_aws_ec2_autoscaling" {
#   source = "../internal-modules/aws-ec2-autoscaling/"

#   autoscaling_group_name = local.name
#   instance_type          = var.instance_type
#   instance_tags          = local.tags

#   network_interfaces = [
#     aws_network_interface.primary.id, # first NIC must be in PUBLIC subnet
#     aws_network_interface.secondary.id,
#   ]

#   # Variables for Tailscale resources
#   tailscale_hostname            = local.name
#   tailscale_auth_key            = tailscale_tailnet_key.main.key
#   tailscale_set_preferences     = var.tailscale_set_preferences
#   tailscale_ssh                 = true
#   tailscale_advertise_exit_node = true

#   tailscale_advertise_routes = [
#     module.vpc.vpc_cidr_block,
#   ]

#   tailscale_advertise_connector = true
#   # tailscale_advertise_aws_service_names = [
#   #   "GLOBALACCELERATOR",
#   # ]

#   depends_on = [
#     module.vpc.natgw_ids, # ensure NAT gateway is available before instance provisioning - primarily for private subnets
#   ]
# }

