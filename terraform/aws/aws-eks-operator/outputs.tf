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
  value = "tailscale configure kubeconfig ${local.operator_name}"
}

output "cmd_kubeconfig_aws" {
  value = "aws eks update-kubeconfig --region ${data.aws_region.current.region} --name ${module.eks.cluster_name}"
}

data "aws_region" "current" {} # TODO: move? or remove?
