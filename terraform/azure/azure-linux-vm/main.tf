locals {
  name = "example-${basename(path.cwd)}"

  azure_tags = {
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
    "--advertise-routes=${join(",", coalescelist(
      local.vpc_cidr_block,
    ))}",
  ]

  // Modify these to use your own VPC
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  vpc_cidr_block            = module.network.vnet_address_space
  vpc_id                    = module.network.vnet_id
  subnet_id                 = module.network.public_subnet_id
  network_security_group_id = azurerm_network_security_group.tailscale_ingress.id
  instance_type             = "Standard_DS1_v2"
  admin_public_key_path     = var.admin_public_key_path
}

resource "azurerm_resource_group" "main" {
  location = "centralus"
  name     = local.name
}

module "network" {
  source = "../internal-modules/azure-network"

  name = local.name
  tags = local.azure_tags

  location            = local.location
  resource_group_name = local.resource_group_name

  cidrs = ["10.0.0.0/22"]
  subnet_cidrs = [
    "10.0.0.0/24",
    "10.0.1.0/24",
    "10.0.2.0/24",
  ]
  subnet_name_public               = "public"
  subnet_name_private              = "private"
  subnet_name_private_dns_resolver = "dns-inbound"
}

#
# Tailscale instance resources
#
resource "tailscale_tailnet_key" "main" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags                = local.tailscale_acl_tags
}

module "tailscale_azure_linux_virtual_machine" {
  source = "../internal-modules/azure-linux-vm"

  location            = local.location
  resource_group_name = local.resource_group_name

  # public subnet
  primary_subnet_id         = local.subnet_id
  network_security_group_id = local.network_security_group_id

  machine_name          = local.name
  machine_size          = local.instance_type
  admin_public_key_path = local.admin_public_key_path
  resource_tags         = local.azure_tags

  # Variables for Tailscale resources
  tailscale_hostname        = local.name
  tailscale_auth_key        = tailscale_tailnet_key.main.key
  tailscale_set_preferences = local.tailscale_set_preferences

  depends_on = [
    module.network.natgw_ids, # for private subnets - ensure NAT gateway is available before instance provisioning
  ]
}

resource "azurerm_network_security_group" "tailscale_ingress" {
  location            = local.location
  resource_group_name = local.resource_group_name

  name = "nsg-tailscale-ingress"

  security_rule {
    name                       = "AllowTailscaleInbound"
    access                     = "Allow"
    direction                  = "Inbound"
    priority                   = 100
    protocol                   = "Udp"
    source_address_prefix      = "Internet"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "41641"
  }
}
