locals {
  cidrs        = length(var.cidrs) == 0 ? [cidrsubnet("10.0.0.0/16", 6, random_integer.vpc_cidr[0].result)] : var.cidrs                                                    # /22
  subnet_cidrs = length(var.subnet_cidrs) == 0 ? [cidrsubnet(local.cidrs[0], 2, 0), cidrsubnet(local.cidrs[0], 2, 1), cidrsubnet(local.cidrs[0], 2, 2)] : var.subnet_cidrs # /24 inside the /22
}

# Pick a random /22 within 10.0.0.0/16
resource "random_integer" "vpc_cidr" {
  count = length(var.cidrs) == 0 ? 1 : 0

  min = 0
  max = 63 # 2^(22-16)-1 = 64 slices in a /16
}

module "vpc" {
  # https://registry.terraform.io/modules/Azure/network/azurerm/latest
  source  = "Azure/network/azurerm"
  version = ">= 5.0, < 6.0"

  resource_group_location = var.location
  resource_group_name     = var.resource_group_name

  vnet_name = var.name
  tags      = var.tags

  address_spaces  = local.cidrs
  subnet_prefixes = local.subnet_cidrs
  subnet_names = [
    var.subnet_name_public,
    var.subnet_name_private,
    var.subnet_name_private_dns_resolver,
  ]

  subnet_delegation = {
    "${var.subnet_name_private_dns_resolver}" = [
      {
        name = "Microsoft.Network/dnsResolvers"
        service_delegation = {
          name = "Microsoft.Network/dnsResolvers"
          actions = [
            "Microsoft.Network/virtualNetworks/subnets/join/action",
          ]
        }
      }
    ]
  }

  use_for_each = true # https://github.com/Azure/terraform-azurerm-network#notice-to-contributor
}

data "azurerm_subnet" "public" {
  resource_group_name = var.resource_group_name

  virtual_network_name = module.vpc.vnet_name
  name                 = var.subnet_name_public

  depends_on = [module.vpc.vnet_subnets]
}

data "azurerm_subnet" "private" {
  resource_group_name = var.resource_group_name

  virtual_network_name = module.vpc.vnet_name
  name                 = var.subnet_name_private

  depends_on = [module.vpc.vnet_subnets]
}

data "azurerm_subnet" "dns-inbound" {
  resource_group_name = var.resource_group_name

  virtual_network_name = module.vpc.vnet_name
  name                 = var.subnet_name_private_dns_resolver

  depends_on = [module.vpc.vnet_subnets]
}
#
# Private DNS resolver resources
#
resource "azurerm_private_dns_resolver" "main" {
  location            = var.location
  resource_group_name = var.resource_group_name

  name = var.name
  tags = var.tags

  virtual_network_id = module.vpc.vnet_id
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "main" {
  location = var.location

  name = var.name
  tags = var.tags

  private_dns_resolver_id = azurerm_private_dns_resolver.main.id

  ip_configurations {
    private_ip_allocation_method = "Dynamic"
    subnet_id                    = data.azurerm_subnet.dns-inbound.id
  }
}

#
# NAT resources
#
resource "azurerm_nat_gateway" "nat" {
  location            = var.location
  resource_group_name = var.resource_group_name

  name                    = var.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}

resource "azurerm_subnet_nat_gateway_association" "nat" {
  nat_gateway_id = azurerm_nat_gateway.nat.id
  subnet_id      = data.azurerm_subnet.private.id
}

resource "azurerm_public_ip" "nat" {
  location            = var.location
  resource_group_name = var.resource_group_name

  name              = "${var.name}-nat"
  sku               = "Standard"
  allocation_method = "Static"
}

resource "azurerm_nat_gateway_public_ip_association" "nat" {
  nat_gateway_id       = azurerm_nat_gateway.nat.id
  public_ip_address_id = azurerm_public_ip.nat.id
}
