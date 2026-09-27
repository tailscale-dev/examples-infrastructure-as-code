output "resource_name_prefix" {
  value = local.name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "autoscaling_group_name" {
  value = module.tailscale_aws_ec2_autoscaling.autoscaling_group_name
}
