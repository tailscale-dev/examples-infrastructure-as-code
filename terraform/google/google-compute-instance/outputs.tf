output "resource_name_prefix" {
  value = local.name
}

output "instance_id" {
  value = module.tailscale_instance.instance_id
}

output "subnets_ips" {
  value = module.vpc.subnets_ips
}
