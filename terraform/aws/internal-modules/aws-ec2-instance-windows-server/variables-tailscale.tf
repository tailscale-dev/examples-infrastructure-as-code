#
# Variables for Tailscale resources
#
variable "tailscale_auth_key" {
  description = "Tailscale auth key to authenticate the device"
  type        = string
}
variable "tailscale_hostname" {
  description = "Hostname to assign to the device"
  type        = string
}
variable "tailscale_msi_url" {
  description = "URL to the Tailscale Windows installer (MSI) to download and install"
  type        = string
  default     = "https://pkgs.tailscale.com/stable/tailscale-setup-latest-amd64.msi"
}

#
# Variables for the local Windows account used to run the Tailscale scheduled task
#
variable "windows_admin_username" {
  description = "Local Windows account used to run the Tailscale scheduled task"
  type        = string
  default     = "Administrator"
}
variable "windows_admin_password" {
  description = "Password to set for `windows_admin_username`. Required so the scheduled task can authenticate as this account. Must not contain a double quote character."
  type        = string
  sensitive   = true
}
