#
# Variables for instance resources
#
variable "zone" {
  type = string
}
variable "subnet" {
  type = string
}
variable "machine_name" {
  type = string
}
variable "machine_type" {
  type = string
}
variable "instance_metadata" {
  type = map(string)
}
variable "instance_tags" {
  type = set(string)
}
