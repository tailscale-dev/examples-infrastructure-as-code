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
variable "tailscale_set_preferences" {
  description = "Preferences to run via `tailscale set ...`. Do not include `tailscale set`."
  type        = set(string)
  default     = []
}

#
# Variables for userdata
#
variable "additional_before_scripts" {
  description = "Additional scripts to run BEFORE Tailscale scripts"
  type        = list(string)
  default     = []
}
variable "additional_after_scripts" {
  description = "Additional scripts to run AFTER Tailscale scripts"
  type        = list(string)
  default     = []
}
