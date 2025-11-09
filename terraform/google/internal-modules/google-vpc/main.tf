locals {
  cidr = length(var.subnets) == 0 ? [cidrsubnet("10.0.0.0/16", 6, random_integer.vpc_cidr[0].result)] : [] # /22
  #   subnets = length(var.subnets) == 0 ? [cidrsubnet(local.cidr[0], 2, 0), cidrsubnet(local.cidr[0], 2, 1)] : var.subnets # /24 inside the /22
  subnets = length(var.subnets) == 0 ? [
    {
      subnet_name   = "subnet-0"
      subnet_ip     = cidrsubnet(local.cidr[0], 2, 0)
      subnet_region = var.region
    },
    {
      subnet_name   = "subnet-1"
      subnet_ip     = cidrsubnet(local.cidr[0], 2, 1)
      subnet_region = var.region
    }
  ] : var.subnets
}

# Pick a random /22 within 10.0.0.0/16
resource "random_integer" "vpc_cidr" {
  count = length(var.subnets) == 0 ? 1 : 0

  min = 0
  max = 63 # 2^(22-16)-1 = 64 slices in a /16
}

module "vpc" {
  # https://registry.terraform.io/modules/terraform-google-modules/network/google/latest
  source  = "terraform-google-modules/network/google"
  version = ">= 7.0, < 8.0"

  project_id   = var.project_id
  network_name = var.name

  subnets = local.subnets
}

module "cloud_router" {
  # https://registry.terraform.io/modules/terraform-google-modules/cloud-router/google/latest
  source  = "terraform-google-modules/cloud-router/google"
  version = ">= 6.0, < 7.0"

  project = var.project_id
  region  = var.region

  name    = var.name
  network = module.vpc.network_name

  nats = [{
    name                               = var.name
    source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
    subnetworks = [
      {
        name                    = module.vpc.subnets_names[0]
        source_ip_ranges_to_nat = ["PRIMARY_IP_RANGE"]
      }
    ]
  }]
}
