#
# Variables for all resources
#
variable "name" {
  description = "Name for all resources"
  type        = string
  default     = ""
}
variable "tags" {
  description = "Map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

#
# Variables for Tailscale
#
variable "tailscale_device_tags" {
  description = "Tailscale device tags to assign"
  type        = set(string)
  default = [
    "tag:example-infra",
    "tag:example-exitnode",
    "tag:example-subnetrouter",
    "tag:example-appconnector",
  ]
}
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
variable "machine_size" {
  type    = string
  default = "Standard_DS1_v2"
}
