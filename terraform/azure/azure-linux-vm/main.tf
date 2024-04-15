locals {
  name = var.name != "" ? var.name : "example-${basename(path.cwd)}"

  tags = length(var.tags) > 0 ? var.tags : {
    Name = local.name
  }
}

resource "azurerm_resource_group" "main" {
  location = var.location
  name     = local.name
}

module "network" {
  source = "../internal-modules/azure-network"

  name = local.name
  tags = local.tags

  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

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
  tags                = var.tailscale_device_tags
}

module "tailscale_azure_linux_virtual_machine" {
  source = "../internal-modules/azure-linux-vm"

  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # public subnet
  primary_subnet_id = module.network.public_subnet_id

  machine_name          = local.name
  machine_size          = var.machine_size
  admin_public_key_path = var.admin_public_key_path
  resource_tags         = local.tags

  # Variables for Tailscale resources
  tailscale_hostname            = local.name
  tailscale_auth_key            = tailscale_tailnet_key.main.key
  tailscale_set_preferences     = var.tailscale_set_preferences
  tailscale_ssh                 = true
  tailscale_advertise_exit_node = true

  tailscale_advertise_routes = module.network.vnet_address_space

  tailscale_advertise_connector = true

  depends_on = [
    module.network.natgw_ids, # for private subnets - ensure NAT gateway is available before instance provisioning
  ]
}
