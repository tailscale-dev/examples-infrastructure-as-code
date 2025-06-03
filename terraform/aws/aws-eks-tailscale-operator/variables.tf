variable "tailscale_oauth_client_id" {
  description = "Tailscale OAuth client ID"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.tailscale_oauth_client_id) > 0
    error_message = "Tailscale OAuth client ID must not be empty."
  }
}

variable "tailscale_oauth_client_secret" {
  description = "Tailscale OAuth client secret"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.tailscale_oauth_client_secret) > 0
    error_message = "Tailscale OAuth client secret must not be empty."
  }
}

 