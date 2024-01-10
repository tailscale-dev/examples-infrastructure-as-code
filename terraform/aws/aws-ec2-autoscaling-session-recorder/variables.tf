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
  ]
}
variable "tailscale_device_tags_recorder" {
  description = "Tailscale device tags to assign to the tsrecorder container"
  type        = set(string)
  default = [
    "tag:example-sessionrecorder",
  ]
}
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
  default = "10.0.80.0/22"
}
variable "public_subnets" {
  type    = list(string)
  default = ["10.0.80.0/24"]
}
variable "private_subnets" {
  type    = list(string)
  default = ["10.0.81.0/24"]
}
variable "instance_type" {
  type    = string
  default = "t4g.micro"
}
