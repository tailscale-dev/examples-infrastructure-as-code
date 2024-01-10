#
# Variables for all resources
#
variable "name" {
  description = "Name for all resources"
  type        = string
  default     = ""
}
variable "tags" {
  description = "Set of tags to add to all resources"
  type        = set(string)
  default     = []
}
variable "metadata" {
  description = "Map of metadata to add to all resources"
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
# Variables for Google resources
#
variable "project_id" {
  description = "The Google Cloud project ID to deploy to"
  type        = string
}
variable "region" {
  description = "The Google Cloud region to deploy to"
  type        = string
}
variable "zone" {
  description = "The Google Cloud zone to deploy to"
  type        = string
}
variable "machine_type" {
  type    = string
  default = "e2-medium"
}
