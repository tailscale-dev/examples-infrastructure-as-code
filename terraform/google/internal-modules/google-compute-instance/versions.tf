terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0, < 5.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.13.13"
    }
  }
}

