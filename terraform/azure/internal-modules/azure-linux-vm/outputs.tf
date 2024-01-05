output "instance_id" {
  value = azurerm_linux_virtual_machine.tailscale_instance.id
}

output "internal_domain_name_suffix" {
  value = azurerm_network_interface.primary.internal_domain_name_suffix
}

output "user_data_md5" {
  description = "MD5 hash of the VM user_data script - for detecting changes"
  value       = module.tailscale_install_scripts.ubuntu_install_script_md5
  sensitive   = true
}
