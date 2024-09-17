locals {
  name = "example-${basename(path.cwd)}"

  google_metadata = {
    Name = local.name
  }

  tailscale_acl_tags = [
    "tag:example-infra",
    "tag:example-exitnode",
    "tag:example-subnetrouter",
    "tag:example-appconnector",
  ]
  tailscale_set_preferences = [
    "--auto-update",
    "--ssh",
    "--advertise-connector",
    "--advertise-exit-node",
    "--advertise-routes=${join(",", coalescelist(
      local.vpc_cidr_block,
    ))}",
  ]

  // Modify these to use your own VPC
  project_id     = var.project_id
  region         = var.region
  zone           = var.zone
  vpc_cidr_block = module.vpc.subnets_ips
  subnet_id      = module.vpc.subnets_ids[0]
  instance_type  = "e2-medium"
  instance_tags  = ["tailscale-instance"]
}

module "vpc" {
  source = "../internal-modules/google-vpc"

  project_id = local.project_id
  region     = local.region

  name = local.name

  subnets = [
    {
      subnet_name   = "subnet-${local.region}-10-0-121"
      subnet_ip     = "10.0.121.0/24"
      subnet_region = local.region
    },
    {
      subnet_name   = "subnet-${local.region}-10-0-122"
      subnet_ip     = "10.0.122.0/24"
      subnet_region = local.region
    }
  ]
}

resource "tailscale_tailnet_key" "main" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags                = local.tailscale_acl_tags
}

module "tailscale_instance" {
  source = "../internal-modules/google-compute-instance"

  zone         = local.zone
  machine_name = local.name
  machine_type = local.instance_type
  subnet       = local.subnet_id

  instance_metadata = local.google_metadata
  instance_tags     = local.instance_tags

  # Variables for Tailscale resources
  tailscale_hostname        = local.name
  tailscale_auth_key        = tailscale_tailnet_key.main.key
  tailscale_set_preferences = local.tailscale_set_preferences

  depends_on = [
    module.vpc.nat_ids, # ensure NAT gateway is available before instance provisioning - primarily for private subnets
  ]
}

resource "google_compute_firewall" "tailscale_ingress_ipv4" {
  name    = "${local.name}-tailscale-ingress-ipv4"
  network = module.vpc.vpc_id

  allow {
    protocol = "udp"
    ports    = ["41641"]
  }

  source_ranges = [
    "0.0.0.0/0",
  ]
  target_tags = local.instance_tags
}

resource "google_compute_firewall" "tailscale_ingress_ipv6" {
  name    = "${local.name}-tailscale-ingress-ipv6"
  network = module.vpc.vpc_id

  allow {
    protocol = "udp"
    ports    = ["41641"]
  }

  source_ranges = [
    "::/0",
  ]
  target_tags = local.instance_tags
}
