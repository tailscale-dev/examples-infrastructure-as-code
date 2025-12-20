terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0, < 8.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.24"
    }
  }

  required_version = ">= 1.0, < 2.0"
}
