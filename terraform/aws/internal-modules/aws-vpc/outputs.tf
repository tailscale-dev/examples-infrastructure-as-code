output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}
output "vpc_ipv6_cidr_block" {
  value = module.vpc.vpc_ipv6_cidr_block
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "azs" {
  value = module.vpc.azs
}

output "nat_public_ips" {
  value = module.vpc.nat_public_ips
}

output "nat_ids" {
  description = "Useful for using within `depends_on` for other resources"
  value       = module.vpc.nat_ids
}

output "public_route_table_ids" {
  value = module.vpc.public_route_table_ids
}

output "private_route_table_ids" {
  value = module.vpc.private_route_table_ids
}
