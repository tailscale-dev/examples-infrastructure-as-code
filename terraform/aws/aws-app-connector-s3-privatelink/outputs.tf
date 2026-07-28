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
  description = "Bucket regional domain. Terraform already points the split DNS entry at this. Add it to the app connector in your policy file."
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}

# The provider has no app connector resource, and the definition lives in the
# policy file, so this one step is manual. Print the exact stanza to paste.
output "next_step_app_connector_policy" {
  description = "Add this to nodeAttrs in your policy file. The connector advertises no routes until you do."
  value       = <<-EOT

    Add this to "nodeAttrs" in your tailnet policy file:

    {
        "target": ["*"],
        "app": {
            "tailscale.com/app-connectors": [
                {
                    "name":       "${local.name}",
                    "connectors": ["tag:example-appconnector"],
                    "domains":    ["${aws_s3_bucket.main.bucket_regional_domain_name}"],
                },
            ],
        },
    },

    Then approve the connector's routes, or add this to "autoApprovers":

    "routes": {
        "0.0.0.0/0": ["tag:example-appconnector"],
    },

    Advertised routes: ${join(", ", local.s3_advertised_routes)}
  EOT
}

output "s3_object_url" {
  description = "Object URL. Returns 200 from a tailnet client using the connector, 403 from the public internet."
  value       = "https://${aws_s3_bucket.main.bucket_regional_domain_name}/${aws_s3_object.main.key}"
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
