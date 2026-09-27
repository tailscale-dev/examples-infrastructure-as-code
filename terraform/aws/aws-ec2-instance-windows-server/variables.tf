variable "windows_admin_password" {
  description = "Password to set for the Windows Administrator account. Required so the Tailscale scheduled task can authenticate. Must not contain a double quote character."
  type        = string
  sensitive   = true
}

variable "tailscale_auth_key" {
  description = "Existing Tailscale auth key to authenticate the device. If not set, a new ephemeral, reusable auth key is created."
  type        = string
  default     = null
  sensitive   = true
}
