output "vpc_id" {
  value = module.network.vnet_id
}

output "nat_public_ips" {
  value = module.network.nat_public_ips
}

output "public_subnet_id" {
  value = module.network.public_subnet_id
}
output "private_subnet_id" {
  value = module.network.private_subnet_id
}

output "private_dns_resolver_inbound_endpoint_ip" {
  value = module.network.private_dns_resolver_inbound_endpoint_ip
}
output "internal_domain_name_suffix" {
  value = module.tailscale_azure_linux_virtual_machine.internal_domain_name_suffix
}

output "instance_id" {
  value = module.tailscale_azure_linux_virtual_machine.instance_id
}

output "user_data_md5" {
  description = "MD5 hash of the VM user_data script - for detecting changes"
  value       = module.tailscale_azure_linux_virtual_machine.user_data_md5
  sensitive   = true
}
