# aws-eks-tailscale-operator

This example creates the following:

- a VPC and related resources including a NAT Gateway
- an EKS cluster with a managed node group
- a Kubernetes namespace for the Tailscale operator with privileged pod security enforcement
- the Tailscale Kubernetes Operator deployed via Helm
- necessary IAM roles and security groups for EKS and Tailscale connectivity

## Considerations

- The EKS cluster is configured with both public and private API server access for flexibility
- The Tailscale operator is deployed in a dedicated `tailscale` namespace with privileged pod security
- OAuth credentials are stored as Kubernetes secrets and passed securely to the Helm chart
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
```

After deployment, configure kubectl to access your cluster:

```shell
aws eks update-kubeconfig --region us-east-1 --name $(terraform output -raw cluster_name)
```

### Verify deployment

Check that the Tailscale operator is running:

```shell
kubectl get pods -n tailscale
kubectl logs -n tailscale -l app.kubernetes.io/name=tailscale-operator
```

## To destroy

```shell
terraform destroy
```

## Customization

You can customize the EKS cluster configuration by modifying the locals in `main.tf`:

- `cluster_version`: EKS Kubernetes version
- `node_instance_type`: EC2 instance type for worker nodes
- `desired_size`, `max_size`, `min_size`: Node group scaling configuration
- VPC CIDR blocks and subnet configurations

The Tailscale operator configuration can be customized in the `helm_release` resource values. 