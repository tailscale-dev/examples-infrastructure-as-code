# aws-ec2-autoscaling-session-recorder

This example creates the following:

- a VPC and related resources including a NAT Gateway
- an EC2 Launch Template and a userdata script to install and configure Tailscale and a [Tailscale SSH session recording container](https://tailscale.com/kb/1246/tailscale-ssh-session-recording)
- an EC2 Autoscaling Group (ASG) using the Launch Template with `min_size`, `max_size`, and `desired_capacity` set to `1`
- a Tailnet device key to authenticate instances launched by the ASG to your Tailnet

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
