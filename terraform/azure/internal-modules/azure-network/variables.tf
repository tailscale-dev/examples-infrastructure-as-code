#
# Variables for all resources
#
variable "resource_group_name" {
  description = "Name of Resource Group for all resources"
  type        = string
}
variable "location" {
  description = "Location for all resources"
  type        = string
}
variable "name" {
  description = "Name for all resources"
  type        = string
}
variable "tags" {
  description = "Map of tags to add to all resources"
  type        = map(string)
}

#
# Variables for network resources
#
variable "cidrs" {
  description = "IPv4 CIDR block for the VPC"
  type        = list(string)
}
variable "subnet_cidrs" {
  description = "List of CIDR blocks"
  type        = list(string)
}
variable "subnet_name_public" {
  description = "Name of the `public` subnet"
  type        = string
}
variable "subnet_name_private" {
  description = "Name of the `private` subnet"
  type        = string
}
variable "subnet_name_private_dns_resolver" {
  description = "Name of the `dns resolver` subnet"
  type        = string
}
