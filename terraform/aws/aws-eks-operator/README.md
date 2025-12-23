# aws-eks-operator

This example creates the following:

- a VPC and related resources including a NAT Gateway
- an EKS cluster with a managed node group
- a Kubernetes namespace for the [Tailscale operator](https://tailscale.com/kb/1236/kubernetes-operator)
- the Tailscale Kubernetes Operator deployed via [Helm](https://tailscale.com/kb/1236/kubernetes-operator#helm)
- a [high availability API server proxy](https://tailscale.com/kb/1437/kubernetes-operator-api-server-proxy#configuring-a-high-availability-api-server-proxy)

## Considerations

- The EKS cluster is configured with both public and private API server access for flexibility
- The Tailscale operator is deployed in a dedicated `tailscale` namespace
- The operator will create a Tailscale device for API server proxy access
- Any additional Tailscale resources (like ingress controllers) created by the operator will appear in your Tailnet

## Prerequisites

- Follow the [Kubernetes Operator prerequisites](https://tailscale.com/kb/1236/kubernetes-operator#prerequisites).
- For the [high availability API server proxy](https://tailscale.com/kb/1437/kubernetes-operator-api-server-proxy#configuring-a-high-availability-api-server-proxy):
    - The configuration as-is currently only works on macOS or Linux clients. Remove or comment out the `null_resource` provisioners that deploy `tailscale-api-server-ha-proxy.yaml`  to run from other platforms.
    - Requires the [kubectl CLI](https://kubernetes.io/docs/reference/kubectl/) and [AWS CLI](https://aws.amazon.com/cli/).


## To use

Follow the documentation to configure the Terraform providers:

- [AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Configure variables

Create a `terraform.tfvars` file with your Tailscale OAuth credentials:

```hcl
tailscale_oauth_client_id     = "your-oauth-client-id"
tailscale_oauth_client_secret = "your-oauth-client-secret"
```

### Deploy

```shell
terraform init
terraform apply
```

#### Verify deployment

After deployment, configure kubectl to access your cluster:

```shell
aws eks update-kubeconfig --region $AWS_REGION --name $(terraform output -raw cluster_name)
```

Check that the Tailscale operator is running:

```shell
kubectl get pods -n tailscale
kubectl logs -n tailscale -l app.kubernetes.io/name=$(terraform output -raw operator_name)
```

#### Verify connectivity via the [API server proxy](https://tailscale.com/kb/1437/kubernetes-operator-api-server-proxy)

After deployment, configure kubectl to access your cluster using Tailscale:

```shell
tailscale configure kubeconfig ${terraform output -raw operator_name}
```

```shell
kubectl get pods -n tailscale
```

## To destroy

```shell
terraform destroy

# remove leftover Tailscale devices at https://login.tailscale.com/admin/machines and services at https://login.tailscale.com/admin/services
```

## Limitations

- The [HA API server proxy](https://tailscale.com/kb/1437/kubernetes-operator-api-server-proxy#configuring-a-high-availability-api-server-proxy) is deployed using a [terraform null_resource](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) instead of [kubernetes_manifest](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest.html) due to a Terraform limitation that results in `cannot create REST client: no client config` errors on first run.
