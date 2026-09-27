# aws-ec2-instance-windows-server

This example creates the following:

- a VPC and related resources including a NAT Gateway
- a Windows Server EC2 instance running Tailscale in a public subnet
- a Tailnet device key to authenticate the Tailscale device, unless you provide the `tailscale_auth_key` input variable

## Considerations

- This example was verified on Windows Server 2022 and Windows Server 2025.
- This example stores the Windows Administrator password and the Tailscale auth key in SSM Parameter Store, as `SecureString` parameters. The instance fetches these values at boot with an IAM role. They do not appear in the userdata script.
- The userdata script authenticates the device with a scheduled task. This task runs at instance launch. Allow 1-2 minutes for the device to appear in the Tailscale Admin Console.
- Connect to the instance with RDP over Tailscale. Do not connect over the public internet. This example does not open TCP port 3389 to the internet.

## Troubleshooting

- The userdata script writes a full log to `C:\Windows\Temp\tailscale-user-data.log`. This log shows each step: parameter retrieval, the password set, the scheduled task creation, and the Tailscale connection check.
- The scheduled task `TailscaleUpOnce` runs `tailscale up`. `schtasks` does not capture the output of a task. The script instead redirects the output of `tailscale up` to `C:\Windows\Temp\tailscale-up-task.log`, then copies it into the userdata log above.
- The task deletes itself after it runs. To check its last run result before then, run:
  ```
  schtasks /query /tn "TailscaleUpOnce" /v /fo list
  ```
- If Tailscale does not connect, the userdata log ends with the full output of `tailscale status`. Use this to find the reason, for example an expired or invalid auth key.
- You need a way to reach the instance to read these logs. Use RDP over Tailscale if the device did connect, or another connection method of your choice if it did not.

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
