locals {
  name = var.name != "" ? var.name : "example-${basename(path.cwd)}"

  tags = length(var.tags) > 0 ? var.tags : ["example"]

  metadata = length(var.metadata) > 0 ? var.metadata : {
    Name = local.name
  }
}

module "vpc" {
  source = "../internal-modules/google-vpc"

  project_id = var.project_id
  region     = var.region

  name = local.name

  subnets = [
    {
      subnet_name   = "subnet-${var.region}-10-0-121"
      subnet_ip     = "10.0.121.0/24"
      subnet_region = var.region
    },
    {
      subnet_name   = "subnet-${var.region}-10-0-122"
      subnet_ip     = "10.0.122.0/24"
      subnet_region = var.region
    }
  ]
}

resource "tailscale_tailnet_key" "main" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags                = var.tailscale_device_tags
}

module "tailscale_instance" {
  source = "../internal-modules/google-compute-instance"

  zone         = var.zone
  machine_name = local.name
  machine_type = var.machine_type
  subnet       = module.vpc.subnets_ids[0]

  instance_metadata = local.metadata
  instance_tags     = local.tags

  # Variables for Tailscale resources
  tailscale_hostname            = local.name
  tailscale_auth_key            = tailscale_tailnet_key.main.key
  tailscale_set_preferences     = var.tailscale_set_preferences
  tailscale_ssh                 = true
  tailscale_advertise_exit_node = true

  tailscale_advertise_routes = module.vpc.subnets_ips

  tailscale_advertise_connector = true
  # tailscale_advertise_github_service_names = [
  #   "api",
  #   "packages",
  #   "website",
  # ]

  depends_on = [
    module.vpc.nat_ids, # ensure NAT gateway is available before instance provisioning - primarily for private subnets
  ]
}
