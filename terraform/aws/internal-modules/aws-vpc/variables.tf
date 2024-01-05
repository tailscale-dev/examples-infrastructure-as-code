#
# Variables for all resources
#
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
variable "azs" {
  description = "A list of availability zones names or ids in the region"
  type        = list(string)
  default     = null
}
variable "cidr" {
  description = "IPv4 CIDR block for the VPC"
  type        = string
}
variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
}
variable "private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
}
variable "enable_ipv6" {
  description = "Conditional to provision IPV6 VPC resources too"
  type        = bool
  default     = false
}
