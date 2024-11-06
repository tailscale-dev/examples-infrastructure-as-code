output "ubuntu_install_script" {
  value = local.ubuntu_install_script
}

output "ubuntu_install_script_base64_encoded" {
  value = base64encode(local.ubuntu_install_script)
}

output "ubuntu_install_script_md5" {
  description = "MD5 hash of the VM user_data script - for detecting changes"
  value       = md5(local.ubuntu_install_script)
}
