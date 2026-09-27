output "resource_name_prefix" {
  value = local.name
}

output "vpc_id" {
  value = module.vpc.vnet_id
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

output "ssh_private_key_openssh" {
  value     = var.admin_public_key_path == "" ? tls_private_key.ssh[0].private_key_openssh : null
  sensitive = true
}
