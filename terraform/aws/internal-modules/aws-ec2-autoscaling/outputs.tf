output "autoscaling_group_names" {
  value = aws_autoscaling_group.tailscale[*].name
}

# For backward compatibility
output "autoscaling_group_name" {
  value = length(aws_autoscaling_group.tailscale) > 0 ? aws_autoscaling_group.tailscale[0].name : ""
}

output "launch_template_ids" {
  value = aws_launch_template.tailscale[*].id
}

output "user_data_md5" {
  value = md5(module.tailscale_install_scripts.ubuntu_install_script_base64_encoded)
}
