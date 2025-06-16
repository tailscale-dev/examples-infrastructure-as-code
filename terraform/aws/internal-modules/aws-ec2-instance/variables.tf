#
# Variables for instance resources
#
variable "subnet_id" {
  type = string
}
variable "ipv6_address_count" {
  type    = number
  default = null
}
variable "vpc_security_group_ids" {
  type = set(string)
}
variable "instance_type" {
  type = string
}
variable "instance_architecture" {
  description = "Architecture of the EC2 instance (arm64 or x86_64)"
  type        = string
  default     = "arm64"
}
variable "instance_tags" {
  type = map(string)
}
variable "instance_user_data_replace_on_change" {
  type    = bool
  default = true
}
variable "instance_key_name" {
  type    = string
  default = ""
}
variable "instance_profile_name" {
  type    = string
  default = null
}
variable "instance_metadata_options" {
  type = map(string)
  # IMDSv2 - not required, but recommended
  default = {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}
