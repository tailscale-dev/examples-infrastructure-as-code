#
# Variables for all resources
#
variable "resource_group_name" {
  description = "The resource group to use"
  type        = string
}
variable "location" {
  description = "The location to use"
  type        = string
}
variable "resource_tags" {
  description = "Tags to assign to all resources created by this module"
  type        = map(string)
}

#
# Variables for virtual machine resources
#
variable "machine_name" {
  description = "The name to assign to the virtual machine"
  type        = string
}
variable "primary_subnet_id" {
  description = "The primary subnet (typically PUBLIC) to assign to the virtual machine"
  type        = string
}
variable "machine_size" {
  description = "The machine size to assign the virtual machine"
  type        = string
}
variable "admin_username" {
  description = "The admin username to assign the virtual machine"
  type        = string
  default     = "ubuntu"
}
variable "admin_public_key_path" {
  description = "The filepath of the SSH public key to assign to the virtual machine"
  type        = string
}
variable "public_ip_address_id" {
  description = "ID of the public address IP to the virtual machine"
  type        = string
  default     = null
}
