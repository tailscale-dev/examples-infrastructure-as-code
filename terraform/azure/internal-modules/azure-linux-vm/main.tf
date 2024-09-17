module "tailscale_install_scripts" {
  source = "../../../internal-modules/tailscale-install-scripts"

  tailscale_auth_key        = var.tailscale_auth_key
  tailscale_hostname        = var.tailscale_hostname
  tailscale_set_preferences = var.tailscale_set_preferences

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
  ip_forwarding_enabled = module.tailscale_install_scripts.ip_forwarding_required
}

resource "azurerm_network_interface_security_group_association" "tailscale" {
  network_interface_id      = azurerm_network_interface.primary.id
  network_security_group_id = var.network_security_group_id
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
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  user_data = module.tailscale_install_scripts.ubuntu_install_script_base64_encoded

  lifecycle {
    ignore_changes = [
      source_image_reference,
    ]
  }
}
