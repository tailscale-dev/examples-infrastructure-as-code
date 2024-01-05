#
# Variables for Tailscale
#
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
