output "vpc_id" {
  description = "VPC ID where the EKS cluster is deployed"
  value       = module.vpc.vpc_id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "tailscale_operator_namespace" {
  description = "Kubernetes namespace where Tailscale operator is deployed"
  value       = kubernetes_namespace_v1.tailscale_operator.metadata[0].name
}

output "cmd_kubeconfig_tailscale" {
  description = "Command to configure kubeconfig for Tailscale access to the EKS cluster"
  value       = "tailscale configure kubeconfig ${helm_release.tailscale_operator.name}"
}

output "cmd_kubeconfig_aws" {
  description = "Command to configure kubeconfig for public access to the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.region} --name ${module.eks.cluster_name}"
}
