#
# Variables for all resources
#
variable "project_id" {
  description = "The Google Cloud project ID to deploy to"
  type        = string
}
variable "region" {
  description = "The Google Cloud region to deploy to"
  type        = string
}
variable "name" {
  description = "Name for all resources"
  type        = string
}

#
# Variables for network resources
#
variable "subnets" {
  description = "List of subnet CIDR blocks"
  type = list(object(
    { subnet_name   = string,
      subnet_ip     = string,
      subnet_region = string
    }
  ))
  default = []
}
