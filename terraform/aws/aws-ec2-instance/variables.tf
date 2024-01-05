#
# Variables for Tailscale
#
variable "tailscale_set_preferences" {
  description = "Preferences to set via `tailscale set ...` - e.g. `--auto-update`. (Do not include `tailscale set`.)"
  type        = set(string)
  default     = []
}

#
# Variables for AWS resources
#
variable "region" {
  type    = string
  default = "us-west-2"
}
variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}
variable "public_subnets" {
  type    = list(string)
  default = ["10.0.101.0/24"]
}
variable "private_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24"]
}
