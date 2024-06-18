# resource "tailscale_tailnet_key" "prod_instance" {
#   ephemeral           = true
#   preauthorized       = true
#   reusable            = true
#   recreate_if_invalid = "always"
#   tags = [
#     "tag:example-infra",
#   ]
# }

# resource "aws_security_group" "prod_instance" {
#   vpc_id = module.prod_vpc.vpc_id

#   tags = merge(local.tags, { Name = "${local.name}-prod-instance" })
# }

# resource "aws_security_group_rule" "prod_instance_vpc_egress" {
#   security_group_id = aws_security_group.prod_instance.id

#   type      = "egress"
#   from_port = 0
#   to_port   = 0
#   protocol  = "-1"
#   cidr_blocks = [
#     "0.0.0.0/0",
#   ]
# }

# resource "aws_security_group_rule" "prod_instance_vpc_ingress" {
#   security_group_id = aws_security_group.prod_instance.id

#   type      = "ingress"
#   from_port = 0
#   to_port   = 0
#   protocol  = "-1"
#   cidr_blocks = [
#     # module.prod_vpc.vpc_cidr_block,
#     "10.0.0.0/8",
#   ]
# }

# module "prod_instance" {
#   source = "../internal-modules/aws-ec2-instance"

#   subnet_id = module.prod_vpc.private_subnets[0]

#   vpc_security_group_ids = [
#     # module.prod_vpc.tailscale_security_group_id,
#     aws_security_group.prod.id,
#   ]

#   instance_type = var.instance_type
#   instance_tags = merge(local.tags, { Name = "${local.name}-prod-instance-private" })

#   # Variables for Tailscale resources
#   tailscale_hostname        = "${local.name}-prod-instance-private"
#   tailscale_auth_key        = tailscale_tailnet_key.prod_instance.key
#   tailscale_set_preferences = var.tailscale_set_preferences
#   tailscale_ssh             = true
#   #   tailscale_advertise_exit_node = true

#   #   tailscale_advertise_routes = [
#   #     module.vpc.vpc_cidr_block,
#   #   ]

#   tailscale_advertise_connector = false
#   # tailscale_advertise_aws_service_names = [
#   #   "GLOBALACCELERATOR",
#   # ]

#   depends_on = [
#     module.prod_vpc.natgw_ids, # ensure NAT gateway is available before instance provisioning - primarily for private subnets
#   ]
# }
