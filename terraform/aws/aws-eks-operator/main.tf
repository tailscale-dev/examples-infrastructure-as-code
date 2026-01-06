locals {
  name                    = "example-${basename(path.cwd)}"
  name_with_random_suffix = "${local.name}-${random_integer.operator_name_suffix.result}"

  aws_tags = {
    Name = local.name
  }

  # Modify these to use your own VPC
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # EKS cluster configuration
  cluster_name       = local.name_with_random_suffix
  cluster_version    = data.aws_eks_cluster_versions.latest.cluster_versions[0].cluster_version
  node_instance_type = "t3.medium"
  desired_size       = 2
  max_size           = 2
  min_size           = 1

  # Tailscale Operator configuration
  namespace_name                = "tailscale"
  operator_name                 = local.name_with_random_suffix
  operator_version              = "1.92.4"
  tailscale_oauth_client_id     = var.tailscale_oauth_client_id
  tailscale_oauth_client_secret = var.tailscale_oauth_client_secret

  enable_ha_proxy_service = true
  ha_proxy_service_name   = "${helm_release.tailscale_operator.name}-ha"
}

# This isn't required but helps avoid conflicts and Let's Encrypt throttling to make testing and iterating easier.
resource "random_integer" "operator_name_suffix" {
  min = 100
  max = 999
}

# Remove this to use your own VPC.
module "vpc" {
  source = "../internal-modules/aws-vpc"

  name = local.name
  tags = local.aws_tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = ">= 21.0, < 22.0"

  name               = local.cluster_name
  kubernetes_version = local.cluster_version

  tags = local.aws_tags

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
      # Truncate the node group name to 20 characters to comply with AWS/EKS
      # node group naming length constraints.
      name           = substr(local.name, 0, 20)
      instance_types = [local.node_instance_type]

      labels = {}

      launch_template_name = local.name
      launch_template_tags = local.aws_tags

      desired_size = local.desired_size
      max_size     = local.max_size
      min_size     = local.min_size
    }
  }
}

resource "kubernetes_namespace_v1" "tailscale_operator" {
  provider = kubernetes.this

  metadata {
    name = local.namespace_name
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }

  depends_on = [
    module.eks,
  ]
}

#
# https://tailscale.com/kb/1236/kubernetes-operator#helm
#
resource "helm_release" "tailscale_operator" {
  provider = helm.this

  name      = local.operator_name
  namespace = kubernetes_namespace_v1.tailscale_operator.metadata[0].name

  repository = "https://pkgs.tailscale.com/helmcharts"
  chart      = "tailscale-operator"
  version    = local.operator_version

  values = [
    yamlencode({
      operatorConfig = {
        image = {
          tag = "v${local.operator_version}"
        }
        hostname = local.operator_name
      }
      apiServerProxyConfig = {
        mode               = "true"
        allowImpersonation = "true"
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

  depends_on = [
    module.eks,
  ]
}

#
# https://tailscale.com/kb/1437/kubernetes-operator-api-server-proxy#configuring-a-high-availability-api-server-proxy
#
# Remove or comment out the `null_resource` provisioners that deploy `tailscale-api-server-ha-proxy.yaml` for the 
# high availability API server proxy to run from other platforms.
#
resource "null_resource" "kubectl_ha_proxy" {
  count = local.enable_ha_proxy_service ? 1 : 0

  triggers = {
    region                = data.aws_region.current.region
    cluster_arn           = module.eks.cluster_arn
    cluster_name          = module.eks.cluster_name
    ha_proxy_service_name = local.ha_proxy_service_name
  }

  #
  # Create provisioners
  #
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name}"
  }
  provisioner "local-exec" {
    command = "HA_PROXY_SERVICE_NAME=${self.triggers.ha_proxy_service_name} envsubst < ${path.module}/tailscale-api-server-ha-proxy.yaml | kubectl apply --context=${self.triggers.cluster_arn} -f -"
  }

  #
  # Destroy provisioners
  #
  provisioner "local-exec" {
    when    = destroy
    command = "aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name}"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "HA_PROXY_SERVICE_NAME=${self.triggers.ha_proxy_service_name} envsubst < ${path.module}/tailscale-api-server-ha-proxy.yaml | kubectl delete --context=${self.triggers.cluster_arn} -f -"
  }

  depends_on = [
    module.vpc, # prevent network changes before this finishes during a destroy
    helm_release.tailscale_operator,
  ]
}
