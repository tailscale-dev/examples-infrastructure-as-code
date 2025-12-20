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

output "instance_ids" {
  value = module.tailscale_aws_ec2[*].instance_id
}

output "user_data_md5" {
  description = "MD5 hash of the VM user_data script - for detecting changes"
  value       = module.tailscale_aws_ec2.user_data_md5
  sensitive   = true
}
