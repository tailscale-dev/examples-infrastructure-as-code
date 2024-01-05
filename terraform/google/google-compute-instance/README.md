# google-compute-instance

This example creates the following:

- a Google Cloud VPC network using the [Google VPC module](https://registry.terraform.io/modules/terraform-google-modules/network/google/latest)
from the Terraform Registry
- a Google Cloud Router and NAT using the [Google Cloud Router module](https://registry.terraform.io/modules/terraform-google-modules/cloud-router/google/latest)
- a Google virtual machine running Tailscale in a public subnet
- a Tailnet device key to authenticate the Tailscale device

## To use

Follow the documentation to configure the Terraform providers:

- [Tailscale](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs)
- [Google](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

### Deploy

```shell
terraform init
terraform apply
```

## To destroy

```shell
terraform destroy
```
