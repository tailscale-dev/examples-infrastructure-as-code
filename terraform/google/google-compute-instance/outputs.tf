output "instance_id" {
  value = module.tailscale_instance.instance_id
}

output "user_data_md5" {
  description = "MD5 hash of the VM user_data script - for detecting changes"
  value       = module.tailscale_instance.user_data_md5
  sensitive   = true
}
