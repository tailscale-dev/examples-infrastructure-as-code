terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0, < 5.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.24"
    }
  }

  required_version = ">= 1.0, < 2.0"
}
