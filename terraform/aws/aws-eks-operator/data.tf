data "aws_region" "current" {}

data "aws_eks_cluster_versions" "latest" {
  default_only = true
}
