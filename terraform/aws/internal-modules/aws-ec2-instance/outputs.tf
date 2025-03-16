output "instance_id" {
  value = aws_instance.tailscale_instance.id
}

output "instance_arn" {
  value = aws_instance.tailscale_instance.arn
}

output "instance_public_ip" {
  value = aws_instance.tailscale_instance.public_ip
}

output "instance_private_ip" {
  value = aws_instance.tailscale_instance.private_ip
}

output "eni_id" {
  value = aws_instance.tailscale_instance.primary_network_interface_id
}

output "user_data_md5" {
  description = "MD5 hash of the VM user_data script - for detecting changes"
  value       = module.tailscale_install_scripts.ubuntu_install_script_md5
  sensitive   = true
}
