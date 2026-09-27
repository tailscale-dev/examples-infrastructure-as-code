# aws-ec2-instance-windows-server

This example creates the following:

- a VPC and related resources including a NAT Gateway
- a Windows Server EC2 instance running Tailscale in a public subnet
- a Tailnet device key to authenticate the Tailscale device

## Considerations

- The userdata script sets the password of the Windows Administrator account to the value of the `windows_admin_password` input variable. AWS does not encrypt userdata. Do not use this method to set a production password. For production use, get the password from a secret store, for example AWS Secrets Manager.
- The userdata script authenticates the device with a scheduled task. This task runs at instance launch. Allow 1-2 minutes for the device to appear in the Tailscale Admin Console.
- Connect to the instance with RDP over Tailscale. Do not connect over the public internet. This example does not open TCP port 3389 to the internet.

## To use

Follow the documentation to configure the Terraform providers:

- [Tailscale](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs)
- [AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Deploy

```shell
terraform init
terraform apply -var="windows_admin_password=<a-strong-password>"
```

## To destroy

```shell
terraform destroy
```
