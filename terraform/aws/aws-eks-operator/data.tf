data "aws_region" "current" {}

data "aws_eks_cluster_versions" "latest" {
  default_only = true
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}
