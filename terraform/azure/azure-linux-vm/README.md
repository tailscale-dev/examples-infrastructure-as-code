# azure-linux-vm

This example creates the following:

- a Virtual Network with `public`, `private`, and `dns-inbound` subnets using the [Azure RM Module for Network](https://registry.terraform.io/modules/Azure/network/azurerm/latest)
from the Terraform Registry
- a Azure NAT Gateway associated with the `private` subnet
- a Azure DNS Private Resolver in the `dns-inbound` subnet
- an Azure Linux virtual machine running Tailscale in a public subnet
- a Tailnet device key to authenticate the Tailscale device

## To use

Follow the documentation to configure the Terraform providers:

- [Tailscale](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs)
- [Azure](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

### Deploy

```shell
terraform init
terraform apply
```

## To destroy

```shell
terraform destroy
```
