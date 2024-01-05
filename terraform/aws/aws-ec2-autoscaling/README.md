# aws-ec2-autoscaling

This example creates the following:

- a VPC and related resources including a NAT Gateway
- an EC2 Launch Template and a userdata script to install and configure Tailscale
- an EC2 Autoscaling Group (ASG) using the Launch Template with `min_size`, `max_size`, and `desired_capacity` set to `1`
- a Tailnet device key to authenticate instances launched by the ASG to your Tailnet

## Considerations

- Any advertised routes and exit nodes must still be approved in the Tailscale Admin Console. The code can be updated to use [Auto Approvers for routes](https://tailscale.com/kb/1018/acls/#auto-approvers-for-routes-and-exit-nodes) if this is configured in your ACLs.

## To use

Follow the documentation to configure the Terraform providers:

- [Tailscale](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs)
- [AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Deploy

```shell
terraform init
terraform apply
```

## To destroy

```shell
terraform destroy
```
