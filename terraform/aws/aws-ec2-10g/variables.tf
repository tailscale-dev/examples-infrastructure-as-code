#
# AWS Provider Variables
#
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_region_2" {
  description = "AWS region to deploy the second EC2 instance"
  type        = string
}

variable "aws_key_pair_name" {
  description = "Name of the AWS key pair for SSH access to EC2 instances"
  type        = string
}

#
# Tailscale Provider Variables (OAuth)
#
variable "tailscale_oauth_client_id" {
  description = "Tailscale OAuth client ID"
  type        = string
  sensitive   = true
}

variable "tailscale_oauth_client_secret" {
  description = "Tailscale OAuth client secret"
  type        = string
  sensitive   = true
}

variable "tailscale_tailnet" {
  description = "Tailscale tailnet name (e.g., example.ts.net)"
  type        = string
} 