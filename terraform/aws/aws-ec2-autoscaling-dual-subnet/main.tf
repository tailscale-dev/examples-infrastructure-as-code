locals {
  name = "example-${basename(path.cwd)}"

  # Add scaling configuration
  max_instances = var.max_instances

  aws_tags = {
    Name = local.name
  }

  tailscale_acl_tags = [
    "tag:example-infra",
    "tag:example-exitnode",
    "tag:example-subnetrouter",
    "tag:example-appconnector",
  ]
  tailscale_set_preferences = [
    "--auto-update",
    "--ssh",
    "--advertise-connector",
    "--advertise-exit-node",
    "--advertise-routes=${join(",", [
      local.vpc_cidr_block,
    ])}",
  ]

  // Modify these to use your own VPC
  vpc_cidr_block     = module.vpc.vpc_cidr_block
  vpc_id             = module.vpc.vpc_id
  subnet_id          = module.vpc.public_subnets[0]
  private_subnet_id  = module.vpc.private_subnets[0]
  security_group_ids = [aws_security_group.tailscale.id]
  instance_type      = var.instance_type
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
  tags                = local.tailscale_acl_tags
}

# Create multiple ENI pairs for scaling
resource "aws_network_interface" "primary" {
  count           = local.max_instances
  subnet_id       = local.subnet_id
  security_groups = local.security_group_ids
  tags            = merge(local.aws_tags, { 
    Name = "${local.name}-primary-${count.index + 1}" 
  })
}

resource "aws_eip" "primary" {
  count = local.max_instances
  tags  = merge(local.aws_tags, { 
    Name = "${local.name}-eip-${count.index + 1}" 
  })
}

resource "aws_eip_association" "primary" {
  count                = local.max_instances
  network_interface_id = aws_network_interface.primary[count.index].id
  allocation_id        = aws_eip.primary[count.index].id
}

resource "aws_network_interface" "secondary" {
  count           = local.max_instances
  subnet_id       = local.private_subnet_id
  security_groups = local.security_group_ids
  tags            = merge(local.aws_tags, { 
    Name = "${local.name}-secondary-${count.index + 1}" 
  })
}

# Flatten the network interfaces for the ASG module
locals {
  # Create pairs: [primary-1, secondary-1, primary-2, secondary-2, ...]
  network_interface_pairs = flatten([
    for i in range(local.max_instances) : [
      aws_network_interface.primary[i].id,
      aws_network_interface.secondary[i].id
    ]
  ])
}

module "tailscale_aws_ec2_autoscaling" {
  source = "../internal-modules/aws-ec2-autoscaling/"

  autoscaling_group_name = local.name
  instance_type          = local.instance_type
  instance_tags          = local.aws_tags

  network_interfaces = local.network_interface_pairs
  desired_capacity   = var.desired_capacity

  # Variables for Tailscale resources
  tailscale_hostname        = local.name
  tailscale_auth_key        = tailscale_tailnet_key.main.key
  tailscale_set_preferences = local.tailscale_set_preferences

  depends_on = [
    module.vpc.nat_ids, # remove if using your own VPC otherwise ensure provisioned NAT gateway is available
  ]
}

resource "aws_security_group" "tailscale" {
  vpc_id = local.vpc_id
  name   = local.name
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
