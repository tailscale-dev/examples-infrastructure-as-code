# Google GKE Dataplane V2 Cluster

This module creates a Google Kubernetes Engine (GKE) cluster with Dataplane V2 (DPv2) enabled using the default CNI, along with a VPC network.

## Features

- GKE Dataplane V2 (DPv2) with default CNI for improved networking and security
- Private cluster configuration
- Workload Identity for secure GCP service access
- Separate node pool with customizable machine types
- VPC with primary and secondary subnets
- Secondary IP ranges for pods and services

## Usage

```hcl
module "gke_cluster" {
  source = "../../google/google-gke-dataplane-v2"

  project_id = "your-gcp-project-id"
  region     = "us-central1"
  
  # Optional parameters
  machine_type = "e2-standard-4"
  node_count   = 3
  
  # Service account for GKE nodes (optional)
  service_account = "your-service-account@your-project.iam.gserviceaccount.com"
  
  # Authorized networks for Kubernetes API
  authorized_networks = [
    {
      name = "office"
      cidr = "192.168.0.0/24"
    },
    {
      name = "home"
      cidr = "10.0.0.0/8"
    }
  ]
}
```

## Requirements

- Google Cloud Project with GKE API enabled
- Service account with necessary permissions
- Terraform 1.0.0 or later
- Google provider 4.47.0 or later

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | The Google Cloud project ID | string | n/a | yes |
| region | The Google Cloud region | string | "us-central1" | no |
| zone | The Google Cloud zone | string | "us-central1-a" | no |
| machine_type | Machine type for GKE nodes | string | "e2-standard-2" | no |
| node_count | Number of nodes in the node pool | number | 3 | no |
| service_account | Service account email for GKE nodes | string | "" | no |
| authorized_networks | List of CIDR blocks that can access the Kubernetes API | list(object) | See variables.tf | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | The ID of the GKE cluster |
| cluster_endpoint | The endpoint for the GKE cluster |
| cluster_ca_certificate | The CA certificate of the GKE cluster |
| vpc_id | The ID of the VPC |
| subnet_ids | The IDs of the subnets | 