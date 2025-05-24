output "vpc_id" {
  value = module.vpc.vpc_id
}

output "nat_public_ips" {
  value = module.vpc.nat_public_ips
}

output "autoscaling_group_names" {
  description = "Names of all autoscaling groups created"
  value       = module.tailscale_aws_ec2_autoscaling.autoscaling_group_names
}

# For backward compatibility
output "autoscaling_group_name" {
  value = module.tailscale_aws_ec2_autoscaling.autoscaling_group_name
}

output "primary_network_interface_ids" {
  description = "IDs of primary (public) network interfaces"
  value       = aws_network_interface.primary[*].id
}

output "secondary_network_interface_ids" {
  description = "IDs of secondary (private) network interfaces"
  value       = aws_network_interface.secondary[*].id
}

output "elastic_ip_addresses" {
  description = "Elastic IP addresses assigned to primary interfaces"
  value       = aws_eip.primary[*].public_ip
}

output "user_data_md5" {
  description = "MD5 hash of the VM user_data script - for detecting changes"
  value       = module.tailscale_aws_ec2_autoscaling.user_data_md5
  sensitive   = true
}
