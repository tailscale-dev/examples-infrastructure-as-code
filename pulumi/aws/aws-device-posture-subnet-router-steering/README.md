# Multi-Region Tailscale Subnet Routers Device Posture Steering

This example shows how to use Pulumi, AWS, and the Tailscale Pulumi provider to deploy a **multi-region network** with steering functionality provided by Custom Posture Attributes and Postures.

## What this project creates

### Tailscale Resources

- `tailscale.OauthClient` used to mint ephemeral auth keys for the subnet routers
- `tailscale.Acl` resource that applies `acl.hujson` to your tailnet  
   (with an explicit `overwriteExistingACL` config flag)

### AWS Resources

For each region in `regionData` (`us-west-2`, `us-east-2`):

- **AWS provider**
- **Network Resources via `NetworkComponent`**
  - One VPC with CIDR `10.0.0.0/16`
  - One public subnet: `10.0.101.0/24`
  - One private subnet: `10.0.1.0/24`
  - Public and private security groups (exposed as `publicSecurityGroup` / `privateSecurityGroup`)

- **Tailscale subnet routers via `TailscaleComponent`**
  - **Two** EC2 instances per region in the **public subnet**
  - Tailscale started with:
    - An **ephemeral, preauthorized auth key** derived from a managed OAuth client
    - `--ssh` enabled
    - `--advertise-routes=10.0.0.0/16`
    - `--advertise-tags=tag:<site-code>`

- **Private demo instance**
  - One EC2 instance per region in the **private subnet**
  - Fixed private IP: `10.0.1.25`

---

## Prerequisites

- **Pulumi CLI** (TypeScript/Node.js project)
- **Node.js**
- **AWS account & credentials** configured
- A **Tailscale tailnet** and a Tailscale **OAuth client** with minimal scopes of `auth_keys`, `devices:posture_attributes`, `devices:posture_attributes:read`, `policy_file`, and `oauth_keys`. (you will likely have to create the parent tag in your ACL to specify with auth_keys before this works)

---

## Setup

This project uses Pulumi config for both its own settings and for the Tailscale provider.

```bash
pulumi install # install required pre-requisites including tailscale-cloudinit generated from Terraform
pulumi stack init {{your_stack_name}}
pulumi config set owner {{your_owner_name}}
pulumi config set overwriteExistingACL true
pulumi config set tailscale:tailnet {{your_tailnet_name}}
pulumi config set tailscale:oauthClientId {{your_oauth_client_id}}
pulumi config set --secret tailscale:oauthClientSecret {{your_oauth_client_secret}}
```

## Test Network Setup

1. Test subnet router communication to private instance

```bash
tailscale ping 10.0.1.25
```

2. Change Subnet routers by changing the subnet_router attribute value using the Admin API

```
curl 'https://api.tailscale.com/api/v2/device/{deviceId}/attributes/subnet_router' \
  --request POST \
  --header 'Content-Type: application/json' \
  --header 'Authorization: Bearer YOUR_SECRET_TOKEN' \
  --data '{
  "value": "usw2",
}'
```

3. Review results of tailscale ping after each value change

```bash
tailscale ping 10.0.1.25
```

### Additional Notes

- This example leverages Pulumi Components, Pulumi Terraform Module, and Tailscale Cloudinit to keep the project clean and organized. These are complex concepts, so this example may be subject to change.
