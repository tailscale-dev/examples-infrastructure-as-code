output "vpc_id_region_1" {
  value = module.vpc.vpc_id
}

output "vpc_id_region_2" {
  value = module.vpc_2.vpc_id
}

output "nat_public_ips_region_1" {
  value = module.vpc.nat_public_ips
}

output "nat_public_ips_region_2" {
  value = module.vpc_2.nat_public_ips
}

output "instance_1_id" {
  value = module.tailscale_aws_ec2_instance_1.instance_id
}

output "instance_1_private_ip" {
  value = module.tailscale_aws_ec2_instance_1.instance_private_ip
}

output "instance_1_public_ip" {
  value = aws_eip.instance_1.public_ip
}

output "instance_2_id" {
  value = module.tailscale_aws_ec2_instance_2.instance_id
}

output "instance_2_private_ip" {
  value = module.tailscale_aws_ec2_instance_2.instance_private_ip
}

output "instance_2_public_ip" {
  value = aws_eip.instance_2.public_ip
}

output "user_data_md5_instance_1" {
  description = "MD5 hash of the VM user_data script for instance 1 - for detecting changes"
  value       = module.tailscale_aws_ec2_instance_1.user_data_md5
  sensitive   = true
}

output "user_data_md5_instance_2" {
  description = "MD5 hash of the VM user_data script for instance 2 - for detecting changes"
  value       = module.tailscale_aws_ec2_instance_2.user_data_md5
  sensitive   = true
} 