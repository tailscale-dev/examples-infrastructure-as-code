#
# Variables for Tailscale
#
variable "tailscale_set_preferences" {
  description = "Preferences to set via `tailscale set ...` - e.g. `--auto-update`. (Do not include `tailscale set`.)"
  type        = set(string)
  default     = []
}

#
# Variables for Azure resources
#
variable "location" {
  type    = string
  default = "centralus"
}
variable "admin_public_key_path" {
  type = string
}
