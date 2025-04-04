locals {
  name = "example-${basename(path.cwd)}"

  google_metadata = {
    Name = local.name
  }

  // Modify these to use your own VPC
  project_id     = var.project_id
  region         = var.region
  zone           = var.zone
  vpc_cidr_block = module.vpc.subnets_ips
  subnet_id      = module.vpc.subnets_ids[0]
  
  // Since we can't use secondary_ranges in the vpc module, we'll define them here
  pod_range_name     = "gke-pod-range"
  service_range_name = "gke-service-range"
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

module "vpc" {
  source = "../internal-modules/google-vpc"

  project_id = local.project_id
  region     = local.region

  name = local.name

  subnets = [
    {
      subnet_name   = "subnet-${local.region}-gke-primary"
      subnet_ip     = "10.0.0.0/20"
      subnet_region = local.region
    },
    {
      subnet_name   = "subnet-${local.region}-gke-secondary"
      subnet_ip     = "10.0.16.0/20"
      subnet_region = local.region
    }
  ]
}

// Create secondary ranges for GKE
resource "google_compute_subnetwork" "gke_subnet" {
  name          = "gke-subnet-${local.region}"
  ip_cidr_range = "10.0.32.0/20"
  region        = local.region
  network       = module.vpc.vpc_id
  project       = local.project_id
  
  secondary_ip_range {
    range_name    = local.pod_range_name
    ip_cidr_range = "10.1.0.0/16"
  }
  
  secondary_ip_range {
    range_name    = local.service_range_name
    ip_cidr_range = "10.2.0.0/20"
  }
}

resource "google_container_cluster" "primary" {
  name     = local.name
  location = local.region
  
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = module.vpc.vpc_id
  subnetwork = google_compute_subnetwork.gke_subnet.self_link

  datapath_provider = "ADVANCED_DATAPATH"  # This enables GKE Dataplane V2 with default CNI

  ip_allocation_policy {
    cluster_secondary_range_name  = local.pod_range_name
    services_secondary_range_name = local.service_range_name
  }

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${local.project_id}.svc.id.goog"
  }

  # Enable Binary Authorization
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Private cluster config
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Logging and monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Master authorized networks (restrict access to K8s master)
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr
        display_name = cidr_blocks.value.name
      }
    }
  }
  
  depends_on = [
    google_compute_subnetwork.gke_subnet
  ]
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "main-node-pool"
  location   = local.region
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    disk_size_gb = 100
    disk_type    = "pd-standard"

    # Google recommends custom service accounts with minimal permissions
    service_account = var.service_account
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Enable workload identity on the nodes
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      env = "dev"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
} 