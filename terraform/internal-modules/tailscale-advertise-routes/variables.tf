/**
 * See other files for vendor-specific variables/outputs - `aws.tf`, `github.tf`, etc.
 */

variable "tailscale_advertise_routes_from_file_on_host" {
  description = "File on the host to append (sorted and distinct) routes to"
  type        = string
}
variable "tailscale_advertise_routes" {
  description = "List of subnets to advertise"
  type        = set(string)
  default     = []
}
