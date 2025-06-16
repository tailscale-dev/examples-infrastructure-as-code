terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.13.13"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "region2"
  region = var.aws_region_2
}

provider "tailscale" {
  oauth_client_id     = var.tailscale_oauth_client_id
  oauth_client_secret = var.tailscale_oauth_client_secret
  tailnet             = var.tailscale_tailnet
} 