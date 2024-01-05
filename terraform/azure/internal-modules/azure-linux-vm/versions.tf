terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0, < 4.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.13.13"
    }
  }
}
