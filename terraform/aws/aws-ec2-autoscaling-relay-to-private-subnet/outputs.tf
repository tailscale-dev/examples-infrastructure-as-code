output "resource_name_prefix" {
  value = local.name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "connector_autoscaling_group_name" {
  value = module.connector.autoscaling_group_name
}

output "relay_autoscaling_group_name" {
  value = module.relay.autoscaling_group_name
}
