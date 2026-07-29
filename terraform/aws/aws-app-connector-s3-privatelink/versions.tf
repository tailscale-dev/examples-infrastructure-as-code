terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0, < 4.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.24"
    }
  }

  required_version = ">= 1.0, < 2.0"
}
