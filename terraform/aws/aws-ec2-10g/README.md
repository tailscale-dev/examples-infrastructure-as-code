# aws-ec2-10g

This example creates the following:

- a VPC and related resources including a NAT Gateway
- 2 EC2 instances using c5.9xlarge instance types (10 Gigabit network performance)
- userdata scripts to install and configure Tailscale on both instances
- Elastic IP addresses for both instances to ensure public IP connectivity
- Security groups configured for high-bandwidth traffic between instances
- A Tailnet device key to authenticate instances to your Tailnet

## Instance Specifications

- **Instance Type**: c5.9xlarge
- **vCPUs**: 36
- **Memory**: 72 GiB
- **Network Performance**: 10 Gigabit
- **EBS Optimized**: Yes
- **Architecture**: x86_64 (Intel/AMD)

## Considerations

- c5.9xlarge instances are designed for high-performance computing workloads
- These instances use x86_64 architecture (Intel/AMD processors), unlike the ARM64-based Graviton instances used in other examples
- The instances are placed in the same subnet for optimal network performance
- Both instances will have public IP addresses via Elastic IPs
- Security groups allow high-bandwidth traffic between instances
- Any advertised routes and exit nodes must still be approved in the Tailscale Admin Console. The code can be updated to use [Auto Approvers for routes](https://tailscale.com/kb/1018/acls/#auto-approvers-for-routes-and-exit-nodes) if this is configured in your ACLs.

## To use

Follow the documentation to configure the Terraform providers:

- [Tailscale](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs)
- [AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Configure Credentials

1. Copy the example variables file:
   ```shell
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` and populate with your actual credentials:
   - **AWS region**: Your preferred AWS region (defaults to us-east-1)
   - **AWS key pair**: Name of your existing AWS key pair for SSH access
   - **Tailscale OAuth credentials**: Get from [Tailscale Admin Console](https://login.tailscale.com/admin/settings/oauth) 
   - **Tailscale tailnet**: Your tailnet name (e.g., `example.ts.net`)

3. Ensure your AWS credentials are configured via environment variables, AWS CLI, or IAM role

4. **Ensure your AWS key pair exists** in the specified region before deploying

### Deploy

```shell
terraform init
terraform apply
```

## SSH Access

Once deployed, you can SSH into the instances using either:

1. **Traditional SSH** via public IP:
   ```shell
   ssh -i ~/.ssh/your-private-key.pem ubuntu@<public-ip>
   ```

2. **Tailscale SSH** (no key required, uses Tailscale authentication):
   ```shell
   tailscale ssh ubuntu@<instance-hostname>
   ```
   
The instances are configured with both methods enabled for maximum flexibility.

## To destroy

```shell
terraform destroy
```

## Testing 10G Performance

Once deployed, you can test the network performance between the instances:

1. SSH into one of the instances via its public IP or Tailscale SSH
2. Install iperf3: `sudo apt update && sudo apt install -y iperf3`
3. Run iperf3 server on one instance: `iperf3 -s`
4. From the other instance, test bandwidth: `iperf3 -c <private-ip-of-other-instance> -t 30`

You should see bandwidth close to 10 Gbps between the instances when testing via their private IP addresses.