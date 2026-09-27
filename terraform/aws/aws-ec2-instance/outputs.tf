output "resource_name_prefix" {
  value = local.name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "instance_ids" {
  value = module.tailscale_aws_ec2[*].instance_id
}
