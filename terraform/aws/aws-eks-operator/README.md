# aws-eks-operator

This example creates the following:

- a VPC and related resources including a NAT Gateway
- an EKS cluster with a managed node group
- a Kubernetes namespace for the [Tailscale operator](https://tailscale.com/kb/1236/kubernetes-operator)
- the Tailscale Kubernetes Operator deployed via [Helm](https://tailscale.com/kb/1236/kubernetes-operator#helm)

## Considerations

- The EKS cluster is configured with both public and private API server access for flexibility
- The Tailscale operator is deployed in a dedicated `tailscale` namespace
- The operator will create a Tailscale device for API server proxy access
- Any additional Tailscale resources (like ingress controllers) created by the operator will appear in your Tailnet

## Prerequisites

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

# execute the output from `terraform output cmd_kubectl_ha_proxy_apply` to deploy the HA proxy
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
# execute the output from `terraform output cmd_kubectl_ha_proxy_delete` to delete the HA proxy

terraform destroy
```
