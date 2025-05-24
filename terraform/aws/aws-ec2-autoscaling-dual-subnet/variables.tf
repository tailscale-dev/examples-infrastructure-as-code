variable "max_instances" {
  description = "Maximum number of instances that can be created"
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Number of instances to run initially"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "c7g.medium"
} 