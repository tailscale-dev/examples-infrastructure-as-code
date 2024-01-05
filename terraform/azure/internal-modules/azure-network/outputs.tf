output "vnet_id" {
  value = module.network.vnet_id
}
output "vnet_name" {
  value = module.network.vnet_name
}
output "vnet_address_space" {
  value = module.network.vnet_address_space
}
output "vnet_subnets" {
  value = module.network.vnet_subnets
}

output "public_subnet_id" {
  value = data.azurerm_subnet.public.id
}
output "public_subnet_name" {
  value = data.azurerm_subnet.public.name
}

output "private_subnet_id" {
  value = data.azurerm_subnet.private.id
}
output "private_subnet_name" {
  value = data.azurerm_subnet.private
}

output "dns_inbound_subnet_id" {
  value = data.azurerm_subnet.dns-inbound.id
}
output "dns_inbound_subnet_name" {
  value = data.azurerm_subnet.dns-inbound.name
}

output "private_dns_resolver_inbound_endpoint_ip" {
  value = azurerm_private_dns_resolver_inbound_endpoint.main.ip_configurations[0].private_ip_address
}

output "nat_public_ips" {
  value = azurerm_public_ip.nat.*.ip_address
}

output "natgw_ids" {
  description = "Useful for using within `depends_on` for other resources"
  value       = azurerm_nat_gateway.nat.*.id
}
