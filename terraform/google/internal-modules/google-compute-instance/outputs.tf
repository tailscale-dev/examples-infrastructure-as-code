output "instance_id" {
  value = google_compute_instance.tailscale_instance.id
}

output "user_data_md5" {
  description = "MD5 hash of the VM user_data script - for detecting changes"
  value       = module.tailscale_install_scripts.ubuntu_install_script_md5
  sensitive   = true
}
