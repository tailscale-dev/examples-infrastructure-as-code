module "vpc" {
  # https://registry.terraform.io/modules/terraform-google-modules/network/google/latest
  source  = "terraform-google-modules/network/google"
  version = ">= 7.0, < 8.0"

  project_id   = var.project_id
  network_name = var.name

  subnets = var.subnets
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
