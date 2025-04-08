variable "project_id" {
  description = "The Google Cloud project ID to deploy to"
  type        = string
}

variable "name" {
  description = "Name for all resources"
  type        = string
}

variable "region" {
  description = "The Google Cloud region to deploy to"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The Google Cloud zone to deploy to"
  type        = string
  default     = "us-central1-a"
}

variable "machine_type" {
  description = "The machine type to use for GKE nodes"
  type        = string
  default     = "e2-standard-2"
}

variable "node_count" {
  description = "Number of nodes in the GKE node pool"
  type        = number
  default     = 1
}

variable "service_account" {
  description = "Service account email for GKE nodes"
  type        = string
  default     = ""
}

variable "authorized_networks" {
  description = "List of CIDR blocks that can access the Kubernetes API"
  type = list(object({
    name = string
    cidr = string
  }))
  default = [
    {
      name = "local"
      cidr = "10.0.0.0/8"
    }
  ]
} 