output "autoscaling_group_name" {
  value = aws_autoscaling_group.tailscale.name
}

output "user_data_md5" {
  description = "MD5 hash of the VM user_data script - for detecting changes"
  value       = module.tailscale_install_scripts.ubuntu_install_script_md5
}
