#
# Variables for dual subnet routing resources
# Typically only used by other modules in this repo - not passed in by the examples themselves. 
#
variable "primary_subnet_cidr" {
  description = "For Dual Subnet only - the CIDR Block of the primary (PUBLIC) subnet. Used to derive the gateway IP."
  type        = string
  default     = null
}
variable "secondary_subnet_cidr" {
  description = "For Dual Subnet only - the CIDR Block of the secondary (PRIVATE) subnet. Used to derive the gateway IP."
  type        = string
  default     = null
}
