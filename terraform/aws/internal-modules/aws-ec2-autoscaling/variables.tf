#
# Variables for autoscaling resources
#
variable "security_group_ids" {
  type = list(string)
}
variable "subnet_id" {
  type = string
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
