module "tailscale_install_scripts" {
  source = "../../../internal-modules/tailscale-install-scripts"

  tailscale_auth_key        = var.tailscale_auth_key
  tailscale_hostname        = var.tailscale_hostname
  tailscale_set_preferences = var.tailscale_set_preferences

  additional_before_scripts = var.additional_before_scripts
  additional_after_scripts  = var.additional_after_scripts
}

data "google_compute_image" "ubuntu" {
  project = "ubuntu-os-cloud"
  family  = "ubuntu-2404-lts-amd64"
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
}
