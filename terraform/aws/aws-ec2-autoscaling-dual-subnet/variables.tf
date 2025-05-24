variable "oauth_client_id" {
  type        = string
  sensitive   = true
  description = <<-EOF
  The OAuth application's ID when using OAuth client credentials.
  Can be set via the TAILSCALE_OAUTH_CLIENT_ID environment variable.
  Both 'oauth_client_id' and 'oauth_client_secret' must be set.
  EOF
}

variable "oauth_client_secret" {
  type        = string
  sensitive   = true
  description = <<-EOF
  (Sensitive) The OAuth application's secret when using OAuth client credentials.
  Can be set via the TAILSCALE_OAUTH_CLIENT_SECRET environment variable.
  Both 'oauth_client_id' and 'oauth_client_secret' must be set.
  EOF
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

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

variable "tailscale_acl_tags" {
  description = "List of Tailscale ACL tags to assign to instances for access control and policy enforcement. Tags must be prefixed with 'tag:' (e.g., ['tag:exitnode', 'tag:subnetrouter'])"
  type        = list(string)
} 