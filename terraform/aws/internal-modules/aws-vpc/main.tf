locals {
  vpc_cidr            = var.cidr == "" ? cidrsubnet("10.0.0.0/16", 6, random_integer.vpc_cidr[0].result) : var.cidr # /22
  public_subnet_cidr  = length(var.public_subnets) == 0 ? [cidrsubnet(local.vpc_cidr, 2, 0)] : var.public_subnets   # /24 inside the /22
  private_subnet_cidr = length(var.private_subnets) == 0 ? [cidrsubnet(local.vpc_cidr, 2, 1)] : var.private_subnets # next /24
}

# Pick a random /22 within 10.0.0.0/16
resource "random_integer" "vpc_cidr" {
  count = var.cidr == "" ? 1 : 0

  min = 0
  max = 63 # 2^(22-16)-1 = 64 slices in a /16
}

module "vpc" {
  # https://github.com/terraform-aws-modules/terraform-aws-vpc
  source  = "terraform-aws-modules/vpc/aws"
  version = ">= 6.0, < 7.0"

  name = var.name
  tags = var.tags

  public_subnet_tags  = merge(var.tags, { Name = "${var.name}-public" })
  private_subnet_tags = merge(var.tags, { Name = "${var.name}-private" })

  azs = var.azs != null ? var.azs : data.aws_availability_zones.available.zone_ids

  cidr            = local.vpc_cidr
  public_subnets  = local.public_subnet_cidr
  private_subnets = local.private_subnet_cidr

  map_public_ip_on_launch = true
  enable_nat_gateway      = true
  single_nat_gateway      = true
  one_nat_gateway_per_az  = false

  # ipv6
  enable_ipv6                                   = var.enable_ipv6
  public_subnet_assign_ipv6_address_on_creation = var.enable_ipv6
  public_subnet_ipv6_prefixes                   = range(0, length(local.public_subnet_cidr))
  private_subnet_ipv6_prefixes                  = range(10, 10 + length(local.private_subnet_cidr))
}

data "aws_availability_zones" "available" {
  state = "available"
}
