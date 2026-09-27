variable "windows_admin_password" {
  description = "Password to set for the Windows Administrator account. Required so the Tailscale scheduled task can authenticate. Must not contain a double quote character."
  type        = string
  sensitive   = true
}
