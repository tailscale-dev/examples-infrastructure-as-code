# azure-aks-k8s

This example creates the following:

- a Virtual Network with appropriate subnets using the [Azure RM Module for Network](https://registry.terraform.io/modules/Azure/network/azurerm/latest)
from the Terraform Registry
- an Azure Kubernetes Service (AKS) cluster with default node pool
- a system-assigned managed identity for the AKS cluster
- Azure CNI networking for better network performance
- Optional Log Analytics workspace for monitoring

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed
- [Terraform](https://www.terraform.io/downloads.html) installed (version >= 1.0)
- Azure subscription and appropriate permissions

## To use

Follow the documentation to configure the Azure provider:

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

## Configuration

The example uses variables with default values that can be overridden. You can create a `terraform.tfvars` file to customize the deployment:

```hcl
resource_group_name = "my-aks-rg"
location           = "westeurope"
cluster_name       = "my-production-cluster"
node_count         = 3
vm_size           = "Standard_D4s_v3"
```

## Outputs

After applying the configuration, Terraform will output:
- `kube_config`: The Kubernetes config file (sensitive)
- `cluster_endpoint`: The AKS cluster endpoint
- `cluster_ca_certificate`: The cluster CA certificate (sensitive)
- `cluster_name`: The name of the AKS cluster
- `resource_group_name`: The name of the resource group

## Features

- Azure CNI networking
- System-assigned managed identity
- Auto-scaling enabled by default
- Customizable node pool configuration
- Network security through VNet integration
- Resource tagging support

## Notes

- The default configuration uses `Standard_D2_v2` VMs which are suitable for development/testing
- For production workloads, consider using larger VM sizes and enabling additional security features
- The network configuration uses Azure CNI for better network performance and security 