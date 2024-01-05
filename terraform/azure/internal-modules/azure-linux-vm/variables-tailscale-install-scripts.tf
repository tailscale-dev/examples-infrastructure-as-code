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
variable "tailscale_ssh" {
  description = "Boolean flag to enable Tailscale SSH"
  type        = bool
  default     = true
}
variable "tailscale_advertise_exit_node" {
  description = "Boolean flag to enable Tailscale Exit Node"
  type        = bool
  default     = false
}
variable "tailscale_advertise_connector" {
  description = "Boolean flag to enable Tailscale App Connector"
  type        = bool
  default     = false
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

#
# Variables for tailscale-advertise-routes
#
variable "tailscale_advertise_routes" {
  description = "List of routes to advertise"
  type        = set(string)
  default     = []
}
variable "tailscale_advertise_aws_service_names" {
  description = "List of AWS Services to retrieve IP prefixes for - e.g. ['GLOBALACCELERATOR','AMAZON']"
  type        = set(string)
  default     = []
}
variable "tailscale_advertise_github_service_names" {
  description = "List of GitHub Services to retrieve IP prefixes for - e.g. ['web','api']"
  type        = set(string)
  default     = []
}
variable "tailscale_advertise_okta_cell_names" {
  description = "List of Okta cells to retrieve IP prefixes for - e.g. ['us_cell_1','emea_cell_2']"
  type        = set(string)
  default     = []
}
