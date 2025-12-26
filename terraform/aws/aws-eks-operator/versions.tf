terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.1.1, < 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0.1, < 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0, < 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0, < 4.0"
    }
  }
}

provider "kubernetes" {
  alias = "this"

  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  alias = "this"

  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
