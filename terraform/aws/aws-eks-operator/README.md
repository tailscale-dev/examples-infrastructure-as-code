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

- The configuration as-is uses currently only works on macOS or Linux clients. Remove or comment out the `null_resource` provisioners that deploy `tailscale-api-server-ha-proxy.yaml` for the [high availability API server proxy](https://tailscale.com/kb/1437/kubernetes-operator-api-server-proxy#configuring-a-high-availability-api-server-proxy) to run from other platforms.
- Requires the [AWS CLI](https://aws.amazon.com/cli/) for initial authentication to the created AWS EKS cluster.
- Create a [Tailscale OAuth Client](https://tailscale.com/kb/1215/oauth-clients#setting-up-an-oauth-client) with appropriate scopes
- Ensure you have AWS CLI configured with appropriate permissions for EKS
- Install `kubectl` for cluster access after deployment

## To use

Follow the documentation to configure the Terraform providers:

- [AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [Helm](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)

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
kubectl logs -n tailscale -l app.kubernetes.io/name=tailscale-operator
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
