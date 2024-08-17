locals {

  name = "example-${basename(path.cwd)}"

  metadata = {
    Name = local.name
  }
  tags = []
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
  tags = [
    "tag:example-infra",
    "tag:example-exitnode",
    "tag:example-subnetrouter",
    "tag:example-appconnector",
  ]
}

module "tailscale_instance" {
  source = "../internal-modules/google-compute-instance"

  zone         = var.zone
  machine_name = local.name
  machine_type = "e2-medium"
  subnet       = module.vpc.subnets_ids[0]

  instance_metadata = local.metadata
  instance_tags     = local.tags

  # Variables for Tailscale resources
  tailscale_hostname = local.name
  tailscale_auth_key = tailscale_tailnet_key.main.key
  tailscale_set_preferences = [
    "--auto-update",
    "--ssh",
    "--advertise-routes=${join(",", module.vpc.subnets_ips)}",
    "--advertise-exit-node=true",
    "--advertise-connector=true",
  ]

  depends_on = [
    module.vpc.nat_ids, # ensure NAT gateway is available before instance provisioning - primarily for private subnets
  ]
}
