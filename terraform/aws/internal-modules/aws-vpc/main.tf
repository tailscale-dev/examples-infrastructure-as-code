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
