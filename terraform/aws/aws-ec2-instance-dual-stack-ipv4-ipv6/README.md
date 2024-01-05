# aws-ec2-instance-dual-stack-ipv4-ipv6

This example creates the following:

- a **dual-stack IPv4/IPv6_** VPC with related resources including a NAT Gateway
- an EC2 instance running Tailscale in a public subnet
- a Tailnet device key to authenticate the Tailscale device

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
