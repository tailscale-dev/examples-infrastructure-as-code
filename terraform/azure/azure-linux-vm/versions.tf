terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.24"
    }
  }

  required_version = ">= 1.0, < 2.0"
}
