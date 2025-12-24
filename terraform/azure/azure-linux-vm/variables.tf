#
# Variables for Azure resources
#
variable "admin_public_key_path" {
  type        = string
  description = "Path to the SSH public key to assign to the virtual machine - if omitted, a key will be created"
  default     = ""
}
