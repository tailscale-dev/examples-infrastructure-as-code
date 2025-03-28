variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "eastus"
}

variable "cluster_name" {
  description = "Name of the AKS cluster (will generate one if empty)"
  type        = string
}

variable "environment" {
  description = "Environment for the resources (e.g., dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the AKS cluster"
  type        = string
  default     = "1.31.6"
}

variable "vm_size" {
  description = "VM size for the AKS node pool"
  type        = string
  default     = "Standard_DS2_v2"
}

variable "enable_auto_scaling" {
  description = "Enable auto scaling for the AKS node pool"
  type        = bool
  default     = true
}

variable "min_count" {
  description = "Minimum number of nodes in the AKS node pool"
  type        = number
  default     = 1
}

variable "max_count" {
  description = "Maximum number of nodes in the AKS node pool"
  type        = number
  default     = 3
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_address_prefixes" {
  description = "Address prefixes for the subnets (requires 3 subnets for nodes, private, and DNS resolver)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "service_cidr" {
  description = "CIDR range for Kubernetes services"
  type        = string
  default     = "172.16.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for Kubernetes DNS service (must be within service_cidr)"
  type        = string
  default     = "172.16.0.10"
}

variable "docker_bridge_cidr" {
  description = "CIDR notation IP for Docker bridge"
  type        = string
  default     = "172.17.0.1/16"
}

variable "availability_zones" {
  description = "List of availability zones to use for the node pool"
  type        = list(number)
  default     = [1, 2, 3]
}

variable "os_disk_size_gb" {
  description = "Disk size for nodes in GB"
  type        = number
  default     = 50
}

variable "os_disk_type" {
  description = "Disk type for nodes"
  type        = string
  default     = "Managed"
}

variable "node_labels" {
  description = "Labels to apply to nodes in the default node pool"
  type        = map(string)
  default     = {}
}

variable "enable_log_analytics_workspace" {
  description = "Enable the creation of a Log Analytics workspace for the AKS cluster"
  type        = bool
  default     = false
}

variable "log_retention_in_days" {
  description = "Number of days to retain logs in Log Analytics"
  type        = number
  default     = 30
} 