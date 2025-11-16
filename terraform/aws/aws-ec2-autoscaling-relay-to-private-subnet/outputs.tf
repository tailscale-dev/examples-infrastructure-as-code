output "resource_name_prefix" {
  value = local.name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr" {
  value = module.vpc.vpc_cidr_block
}

output "nat_public_ips" {
  value = module.vpc.nat_public_ips
}

output "connector_autoscaling_group_name" {
  value = module.connector.autoscaling_group_name
}

output "relay_autoscaling_group_name" {
  value = module.relay.autoscaling_group_name
}

output "connector_user_data_md5" {
  description = "MD5 hash of the VM user_data script - for detecting changes"
  value       = module.connector.user_data_md5
  sensitive   = true
}

output "relay_user_data_md5" {
  description = "MD5 hash of the VM user_data script - for detecting changes"
  value       = module.relay.user_data_md5
  sensitive   = true
}
