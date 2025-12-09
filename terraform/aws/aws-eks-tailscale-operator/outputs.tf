output "vpc_id" {
  description = "VPC ID where the EKS cluster is deployed"
  value       = module.vpc.vpc_id
}

output "nat_public_ips" {
  description = "Public IPs of the NAT Gateways"
  value       = module.vpc.nat_public_ips
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.main.arn
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "node_group_arn" {
  description = "EKS node group ARN"
  value       = aws_eks_node_group.main.arn
}

output "tailscale_operator_namespace" {
  description = "Kubernetes namespace where Tailscale operator is deployed"
  value       = kubernetes_namespace.tailscale_operator.metadata[0].name
} 