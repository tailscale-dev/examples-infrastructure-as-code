#
# Variables for autoscaling resources
#
variable "network_interfaces" {
  description = "List of network interfaces to attach to instances - if attaching multiple for dual subnet routing, the first NIC must be the primary in the PUBLIC subnet. Should be in pairs: [public-1, private-1, public-2, private-2, ...]"
  type        = list(string)
}
variable "interfaces_per_instance" {
  description = "Number of network interfaces per instance (typically 2 for dual-homed)"
  type        = number
  default     = 2
}
variable "desired_capacity" {
  description = "Number of instances to run"
  type        = number
  default     = 1
}
variable "autoscaling_group_name" {
  type = string
}
variable "instance_type" {
  type = string
}
variable "instance_tags" {
  type = map(string)
}
variable "instance_key_name" {
  type    = string
  default = ""
}
variable "instance_profile_name" {
  type    = string
  default = ""
}
variable "instance_metadata_options" {
  type = map(string)
  # IMDSv2 - not required, but recommended
  default = {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}
