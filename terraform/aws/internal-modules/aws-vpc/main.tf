data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  # https://github.com/terraform-aws-modules/terraform-aws-vpc
  source  = "terraform-aws-modules/vpc/aws"
  version = ">= 5.0, < 6.0"

  name = var.name
  tags = var.tags

  cidr = var.cidr

  azs             = var.azs != null ? var.azs : data.aws_availability_zones.available.zone_ids
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  map_public_ip_on_launch = true
  enable_nat_gateway      = true
  single_nat_gateway      = true
  one_nat_gateway_per_az  = false

  # ipv6
  enable_ipv6                                   = var.enable_ipv6
  public_subnet_assign_ipv6_address_on_creation = var.enable_ipv6
  public_subnet_ipv6_prefixes                   = range(0, length(var.public_subnets))
  private_subnet_ipv6_prefixes                  = range(10, 10 + length(var.private_subnets))
}

resource "aws_security_group" "tailscale" {
  vpc_id = module.vpc.vpc_id
  name   = var.name
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
  cidr_blocks       = [var.cidr]
}

resource "aws_security_group_rule" "internal_vpc_ingress_ipv6" {
  count = var.enable_ipv6 == false ? 0 : 1

  security_group_id = aws_security_group.tailscale.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  ipv6_cidr_blocks  = [module.vpc.vpc_ipv6_cidr_block]
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
