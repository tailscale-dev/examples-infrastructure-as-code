# Output the cluster's credentials
output "kube_config" {
  description = "Raw kubeconfig content for the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = azurerm_kubernetes_cluster.aks.kube_config.0.host
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64 encoded certificate authority of the Kubernetes cluster"
  value       = azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate
  sensitive   = true
}

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "resource_group_name" {
  description = "Name of the resource group containing the AKS cluster"
  value       = azurerm_resource_group.aks.name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.vpc.vnet_id
}

output "principal_id" {
  description = "Principal ID of the AKS cluster identity"
  value       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

output "node_resource_group" {
  description = "Auto-generated resource group for the AKS cluster nodes"
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
} 