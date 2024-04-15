module "tailscale_install_scripts" {
  source = "../../../internal-modules/tailscale-install-scripts"

  tailscale_advertise_connector = var.tailscale_advertise_connector
  tailscale_advertise_exit_node = var.tailscale_advertise_exit_node
  tailscale_auth_key            = var.tailscale_auth_key
  tailscale_hostname            = var.tailscale_hostname
  tailscale_set_preferences     = var.tailscale_set_preferences
  tailscale_ssh                 = var.tailscale_ssh

  tailscale_advertise_routes            = var.tailscale_advertise_routes
  tailscale_advertise_aws_service_names = var.tailscale_advertise_aws_service_names

  additional_before_scripts = var.additional_before_scripts
  additional_after_scripts  = var.additional_after_scripts
}

resource "azurerm_network_interface" "primary" {
  location            = var.location
  resource_group_name = var.resource_group_name

  name = "${var.machine_name}-primary"
  tags = var.resource_tags

  internal_dns_name_label = "${var.machine_name}-primary"
  ip_configuration {
    subnet_id                     = var.primary_subnet_id
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.public_ip_address_id
  }
  enable_ip_forwarding = module.tailscale_install_scripts.ip_forwarding_required
}

resource "azurerm_network_interface_security_group_association" "tailscale" {
  network_interface_id      = azurerm_network_interface.primary.id
  network_security_group_id = azurerm_network_security_group.tailscale_ingress.id
}

resource "azurerm_network_security_group" "tailscale_ingress" {
  location            = var.location
  resource_group_name = var.resource_group_name

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

resource "azurerm_linux_virtual_machine" "tailscale_instance" {
  location            = var.location
  resource_group_name = var.resource_group_name

  name = var.machine_name
  tags = var.resource_tags
  size = var.machine_size

  network_interface_ids = [azurerm_network_interface.primary.id]

  admin_username = var.admin_username
  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.admin_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  user_data = module.tailscale_install_scripts.ubuntu_install_script_base64_encoded

  lifecycle {
    ignore_changes = [
      source_image_reference,
    ]
  }
}
