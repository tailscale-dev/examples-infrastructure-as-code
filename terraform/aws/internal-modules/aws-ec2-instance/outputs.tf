output "instance_id" {
  value = aws_instance.tailscale_instance.id
}

output "instance_private_ip" {
  value = aws_instance.tailscale_instance.private_ip
}

output "user_data_md5" {
  description = "MD5 hash of the VM user_data script - for detecting changes"
  value       = module.tailscale_install_scripts.ubuntu_install_script_md5
  sensitive   = true
}
