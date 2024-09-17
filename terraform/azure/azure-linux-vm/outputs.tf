output "vpc_id" {
  value = module.vpc.vnet_id
}

output "nat_public_ips" {
  value = module.vpc.nat_public_ips
}

output "public_subnet_id" {
  value = module.vpc.public_subnet_id
}
output "private_subnet_id" {
  value = module.vpc.private_subnet_id
}

output "private_dns_resolver_inbound_endpoint_ip" {
  value = module.vpc.private_dns_resolver_inbound_endpoint_ip
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
