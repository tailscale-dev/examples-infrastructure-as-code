output "vpc_id" {
  value = module.vpc.network_id
}

output "subnets_ids" {
  value = module.vpc.subnets_ids
}

output "subnets_ips" {
  value = module.vpc.subnets_ips
}

output "nat_ids" {
  description = "Useful for using within `depends_on` for other resources"
  value       = [for nat in module.cloud_router.nat : nat.id]
}
