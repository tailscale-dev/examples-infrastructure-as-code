module "tailscale_install_scripts" {
  source = "../../../internal-modules/tailscale-install-scripts"

  tailscale_auth_key        = var.tailscale_auth_key
  tailscale_hostname        = var.tailscale_hostname
  tailscale_set_preferences = var.tailscale_set_preferences

  additional_before_scripts = var.additional_before_scripts
  additional_after_scripts  = var.additional_after_scripts
}

data "google_compute_subnetwork" "selected" {
  self_link = "https://www.googleapis.com/compute/v1/${var.subnet}" # requires full URL - https://github.com/hashicorp/terraform-provider-google/issues/9919
}

resource "google_compute_firewall" "tailscale_ingress_ipv4" {
  name    = "tailscale-ingress-ipv4"
  network = data.google_compute_subnetwork.selected.network

  allow {
    protocol = "udp"
    ports    = ["41641"]
  }

  source_ranges = [
    "0.0.0.0/0",
  ]
  target_tags = var.instance_tags
}

resource "google_compute_firewall" "tailscale_ingress_ipv6" {
  name    = "tailscale-ingress-ipv6"
  network = data.google_compute_subnetwork.selected.network

  allow {
    protocol = "udp"
    ports    = ["41641"]
  }

  source_ranges = [
    "::/0",
  ]
  target_tags = var.instance_tags
}

data "google_compute_image" "ubuntu" {
  project = "ubuntu-os-cloud"
  family  = "ubuntu-2204-lts"
}

resource "google_compute_instance" "tailscale_instance" {
  zone         = var.zone
  name         = var.machine_name
  machine_type = var.machine_type

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
    }
  }

  network_interface {
    subnetwork = var.subnet
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = var.instance_metadata
  tags     = var.instance_tags

  metadata_startup_script = module.tailscale_install_scripts.ubuntu_install_script
  can_ip_forward          = module.tailscale_install_scripts.ip_forwarding_required
}
