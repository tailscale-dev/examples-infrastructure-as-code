output "resource_name_prefix" {
  value = local.name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr" {
  value = module.vpc.vpc_cidr_block
}

output "instance_ids" {
  value = module.tailscale_aws_ec2[*].instance_id
}

output "s3_bucket" {
  description = "Name of the bucket reachable over PrivateLink"
  value       = aws_s3_bucket.main.bucket
}

output "s3_domain" {
  description = "Bucket regional domain. This is the app connector domain and the split DNS domain."
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}

output "s3_object_url" {
  description = "Object URL. Returns 200 from a tailnet client using the connector, 403 from the public internet."
  value       = "https://${aws_s3_bucket.main.bucket_regional_domain_name}/hello.txt"
}

output "s3_vpc_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}

output "s3_advertised_routes" {
  description = "Routes the connector advertises: the VPC resolver and the endpoint ENI"
  value       = local.s3_advertised_routes
}

output "user_data_md5" {
  description = "MD5 hash of the VM user_data script - for detecting changes"
  value       = module.tailscale_aws_ec2.user_data_md5
  sensitive   = true
}
