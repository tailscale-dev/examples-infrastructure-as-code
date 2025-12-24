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
      tolist(local.vpc_cidr_block),
    ))}",
  ]

  # Modify these to use your own VPC
  resource_group_id   = azurerm_resource_group.main.id
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  vpc_cidr_block            = module.vpc.vnet_address_space
  subnet_id                 = module.vpc.public_subnet_id
  network_security_group_id = azurerm_network_security_group.tailscale_ingress.id
  instance_type             = "Standard_D2as_v6"
  admin_public_key          = var.admin_public_key_path == "" ? tls_private_key.ssh[0].public_key_pem : file(var.admin_public_key_path)
}

resource "azurerm_resource_group" "main" {
  location = "centralus"
  name     = local.name
}

module "vpc" {
  source = "../internal-modules/azure-network"

  name = local.name
  tags = local.azure_tags

  location            = local.location
  resource_group_id   = local.resource_group_id
  resource_group_name = local.resource_group_name

  subnet_name_public               = "public"
  subnet_name_private              = "private"
  subnet_name_private_dns_resolver = "dns-inbound"
}

resource "tls_private_key" "ssh" {
  count     = var.admin_public_key_path == "" ? 1 : 0
  algorithm = "ED25519"
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

resource "azurerm_public_ip" "vm" {
  location            = local.location
  resource_group_name = local.resource_group_name

  name = "${local.resource_group_name}-vm"
  tags = local.azure_tags

  sku               = "Standard"
  allocation_method = "Static"
  zones             = []
}

module "tailscale_azure_linux_virtual_machine" {
  source = "../internal-modules/azure-linux-vm"

  location            = local.location
  resource_group_name = local.resource_group_name

  # public subnet
  primary_subnet_id         = local.subnet_id
  network_security_group_id = local.network_security_group_id
  public_ip_address_id      = azurerm_public_ip.vm.id

  machine_name     = local.name
  machine_size     = local.instance_type
  admin_public_key = local.admin_public_key
  resource_tags    = local.azure_tags

  # Variables for Tailscale resources
  tailscale_hostname        = local.name
  tailscale_auth_key        = tailscale_tailnet_key.main.key
  tailscale_set_preferences = local.tailscale_set_preferences

  depends_on = [
    module.vpc.nat_ids, # remove if using your own VPC otherwise ensure provisioned NAT gateway is available
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
