locals {
  name = "example-${basename(path.cwd)}"

  aws_tags = {
    Name = local.name
  }

  // Modify these to use your own VPC
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # EKS cluster configuration
  cluster_version    = "1.34" # TODO: omit this?
  node_instance_type = "t3.medium"
  desired_size       = 2
  max_size           = 2
  min_size           = 1

  # Tailscale Operator configuration
  operator_name                 = "${local.name}-operator"
  operator_version              = "1.92.4"
  tailscale_oauth_client_id     = var.tailscale_oauth_client_id
  tailscale_oauth_client_secret = var.tailscale_oauth_client_secret
}

// Remove this to use your own VPC.
module "vpc" {
  source = "../internal-modules/aws-vpc"

  name = local.name
  tags = local.aws_tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = ">= 21.0, < 22.0"

  name               = local.name
  kubernetes_version = local.cluster_version

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  # Once the Tailscale operator is installed, `endpoint_public_access` can be disabled.
  # This is left enabled for the sake of easy adoption. 
  endpoint_public_access = true

  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  vpc_id     = local.vpc_id
  subnet_ids = local.subnet_ids

  eks_managed_node_groups = {
    main = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      #   ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = [local.node_instance_type]

      desired_size = local.desired_size
      max_size     = local.max_size
      min_size     = local.min_size
    }
  }

  tags = local.aws_tags
}

# Kubernetes namespace for Tailscale operator
resource "kubernetes_namespace_v1" "tailscale_operator" {
  metadata {
    name = "tailscale"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

resource "helm_release" "tailscale_operator" {
  name      = local.operator_name
  namespace = kubernetes_namespace_v1.tailscale_operator.metadata[0].name

  repository = "https://pkgs.tailscale.com/helmcharts"
  chart      = "tailscale-operator"
  version    = local.operator_version

  values = [
    yamlencode({
      operatorConfig = {
        image = {
          repo = "tailscale/k8s-operator"
          tag  = "v${local.operator_version}"
        }
        hostname = local.operator_name
      }
      apiServerProxyConfig = {
        mode = true
        tags = "tag:k8s-operator,tag:k8s-api-server"
      }
    })
  ]

  set_sensitive = [
    {
      name  = "oauth.clientId"
      value = local.tailscale_oauth_client_id
    },
    {
      name  = "oauth.clientSecret"
      value = local.tailscale_oauth_client_secret
    },
  ]
}

# TODO: get working on first apply?
# locals {
#   # TODO: inline/simplify?
#   yaml_tailscale_operator_ha_proxy = <<-EOT
#         apiVersion: tailscale.com/v1alpha1
#         kind: ProxyGroup
#         metadata:
#             name: ${helm_release.tailscale_operator.name}-ha
#         spec:
#             type: kube-apiserver
#             replicas: 2
#             tags: ["tag:k8s"]
#             kubeAPIServer:
#                 mode: auth
#     EOT
# }

# resource "kubernetes_manifest" "tailscale_operator_ha_proxy" {
#   manifest = yamldecode(local.yaml_tailscale_operator_ha_proxy)

#   depends_on = [
#     module.eks.cluster_endpoint, # TODO: remove?
#     helm_release.tailscale_operator,
#     kubernetes_namespace_v1.tailscale_operator,
#   ]
# }
