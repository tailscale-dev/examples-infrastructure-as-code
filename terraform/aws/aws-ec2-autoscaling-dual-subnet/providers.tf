provider "tailscale" {
  oauth_client_id     = var.oauth_client_id
  oauth_client_secret = var.oauth_client_secret
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}