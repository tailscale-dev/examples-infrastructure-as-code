provider "aws" {
  region = "us-west-2"
}

data "aws_availability_zones" "available" {}

# module "staging_vpc" {
#   source = "terraform-aws-modules/vpc/aws"

#   name = local.name

#   cidr = "10.0.0.0/20"
#   public_subnets = [
#     "10.0.0.0/24",
#     "10.0.1.0/24",
#     "10.0.2.0/24",
#   ]
#   private_subnets = [
#     "10.0.4.0/24",
#     "10.0.5.0/24",
#     "10.0.6.0/24",
#   ]

#   azs = local.azs
#   # public_subnets  = [for k, v in local.azs : cidrsubnet(local.mgmt_vpc_cidr, 8, k)]
#   # private_subnets = [for k, v in local.azs : cidrsubnet(local.staging_vpc_cidr, 8, k + 10)]

#   enable_nat_gateway                             = true
#   single_nat_gateway                             = true
#   enable_dns_hostnames                           = false
#   enable_ipv6                                    = false
#   public_subnet_enable_dns64                     = false
#   private_subnet_assign_ipv6_address_on_creation = false
#   # private_subnet_ipv6_prefixes                   = [0, 1, 2]

#   # Manage so we can name
#   manage_default_network_acl    = true
#   default_network_acl_tags      = { Name = "${local.staging_name}-default" }
#   manage_default_route_table    = true
#   default_route_table_tags      = { Name = "${local.staging_name}-default" }
#   manage_default_security_group = true
#   default_security_group_tags   = { Name = "${local.staging_name}-default" }

#   tags                = merge(var.tags, { Name = "${local.name}-staging" })
#   public_subnet_tags  = merge(var.tags, { Name = "${local.name}-staging-public" })
#   private_subnet_tags = merge(var.tags, { Name = "${local.name}-staging-private" })
# }

module "prod_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = local.prod_name

  cidr = "10.1.0.0/20"
  public_subnets = [
    "10.1.0.0/24",
    "10.1.1.0/24",
    "10.1.2.0/24",
  ]
  private_subnets = [
    "10.1.4.0/24", # TODO: should start at 3
    "10.1.5.0/24",
    "10.1.6.0/24",
  ]

  azs = local.azs
  # public_subnets  = [for k, v in local.azs : cidrsubnet(local.prod_vpc_cidr, 8, k)]
  # private_subnets = [for k, v in local.azs : cidrsubnet(local.prod_vpc_cidr, 8, k + 10)]

  enable_nat_gateway                             = true
  single_nat_gateway                             = true
  enable_dns_hostnames                           = false
  enable_ipv6                                    = false
  public_subnet_enable_dns64                     = false
  private_subnet_assign_ipv6_address_on_creation = false
  # private_subnet_ipv6_prefixes                   = [0, 1, 2]

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-prod-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-prod-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-prod-default" }

  tags                     = merge(var.tags, { Name = "${local.name}-prod" })
  public_subnet_tags       = merge(var.tags, { Name = "${local.name}-prod-public" })
  private_subnet_tags      = merge(var.tags, { Name = "${local.name}-prod-private" })
  public_route_table_tags  = merge(var.tags, { Name = "${local.name}-prod-public" })
  private_route_table_tags = merge(var.tags, { Name = "${local.name}-prod-private" })
}

module "mgmt_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = local.mgmt_name

  cidr = "10.2.0.0/20"
  public_subnets = [
    "10.2.0.0/24",
    "10.2.1.0/24",
    "10.2.2.0/24",
  ]
  private_subnets = [
    "10.2.4.0/24", # TODO: should start at 3
    "10.2.5.0/24",
    "10.2.6.0/24",
  ]
  azs = local.azs
  # public_subnets  = [for k, v in local.azs : cidrsubnet(local.mgmt_vpc_cidr, 8, k)]
  # private_subnets = [for k, v in local.azs : cidrsubnet(local.mgmt_vpc_cidr, 8, k + 10)]

  enable_nat_gateway                             = true
  single_nat_gateway                             = true
  enable_dns_hostnames                           = false
  enable_ipv6                                    = false
  public_subnet_enable_dns64                     = false
  private_subnet_assign_ipv6_address_on_creation = false
  # private_subnet_ipv6_prefixes                   = [0, 1, 2]

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-mgmt-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-mgmt-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-mgmt-default" }

  tags                     = merge(var.tags, { Name = "${local.name}-mgmt" })
  public_subnet_tags       = merge(var.tags, { Name = "${local.name}-mgmt-public" })
  private_subnet_tags      = merge(var.tags, { Name = "${local.name}-mgmt-private" })
  public_route_table_tags  = merge(var.tags, { Name = "${local.name}-mgmt-public" })
  private_route_table_tags = merge(var.tags, { Name = "${local.name}-mgmt-private" })
}


################################################################################
# Transit Gateway Module
################################################################################

module "tgw" {
  source = "terraform-aws-modules/transit-gateway/aws"

  name        = local.name
  description = "My TGW shared with Mutliple VPC"
  # When "true" there is no need for RAM resources if using multiple AWS accounts
  enable_auto_accept_shared_attachments = true

  enable_default_route_table_association = false
  enable_default_route_table_propagation = false

  transit_gateway_cidr_blocks = [
    # "10.99.0.0/24",
    "10.0.0.0/8",
  ]
  # When "true", allows service discovery through IGMP
  # enable_mutlicast_support = false

  vpc_attachments = {
    # staging_vpc = {
    #   vpc_id       = module.staging_vpc.vpc_id
    #   subnet_ids   = module.staging_vpc.private_subnets
    #   dns_support  = true
    #   ipv6_support = false

    #   transit_gateway_default_route_table_association = false
    #   transit_gateway_default_route_table_propagation = false

    #   tgw_routes = [
    #     {
    #       destination_cidr_block = module.staging_vpc.vpc_cidr_block
    #     }
    #   ]
    # },
    prod_vpc = {
      vpc_id     = module.prod_vpc.vpc_id
      subnet_ids = module.prod_vpc.private_subnets

      transit_gateway_default_route_table_association = false
      transit_gateway_default_route_table_propagation = false

      tgw_routes = [
        # TODO: for_each this or something
        { destination_cidr_block = "10.1.4.0/24" },
        { destination_cidr_block = "10.1.5.0/24" },
        { destination_cidr_block = "10.1.6.0/24" },
      ]
    },
    mgmt_vpc = {
      vpc_id     = module.mgmt_vpc.vpc_id
      subnet_ids = module.mgmt_vpc.private_subnets

      transit_gateway_default_route_table_association = false
      transit_gateway_default_route_table_propagation = false

      tgw_routes = [
        # TODO: for_each this or something
        { destination_cidr_block = "10.2.4.0/24" },
        { destination_cidr_block = "10.2.5.0/24" },
        { destination_cidr_block = "10.2.6.0/24" },
      ]
    },
  }
}

resource "aws_route" "prod_vpc_tgw_route" {
  # TODO: for_each this or something
  route_table_id         = module.prod_vpc.private_route_table_ids[0]
  destination_cidr_block = "10.2.0.0/20"
  transit_gateway_id     = module.tgw.ec2_transit_gateway_id
}

resource "aws_route" "mgmt_vpc_tgw_route" {
  # TODO: for_each this or something
  route_table_id         = module.mgmt_vpc.private_route_table_ids[0]
  destination_cidr_block = "10.1.0.0/20"
  transit_gateway_id     = module.tgw.ec2_transit_gateway_id
}
