# aws-app-connector-s3-privatelink

> :information_source: This example routes traffic for **one specific S3 bucket** over a private path. Every other bucket, and all other traffic, continues to egress publicly. A use case for this is keeping one sensitive bucket off the public internet without changing how anything else is reached.

Pointing an app connector at a public S3 endpoint does not work well. S3 regional endpoints resolve to a large pool of addresses that rotates, so the connector keeps discovering new addresses and the advertised route set grows without settling. This example gives the bucket a stable private address first, then advertises that.

This example creates the following:

- a VPC and related resources including a NAT Gateway
- a private S3 bucket with one object, readable only through the VPC endpoint
- an S3 interface VPC endpoint (AWS PrivateLink) with private DNS, scoped by policy to that one bucket
- an EC2 instance running Tailscale as an app connector, advertising the VPC resolver and the endpoint ENI
- a Tailscale split DNS entry mapping the bucket domain to the VPC resolver
- a Tailnet device key to authenticate the Tailscale device

## How it works

Three pieces have to line up.

The **interface endpoint** gives the bucket a private address. With `private_dns_enabled` and `private_dns_only_for_inbound_resolver_endpoint = false`, resolving the bucket domain inside the VPC returns the endpoint ENI instead of a public address.

**Split DNS** sends only that one name to the VPC resolver. The domain is the exact bucket FQDN, not `s3.<region>.amazonaws.com`. Split DNS matches a domain and its subdomains, not its siblings, so other buckets never match and stay public.

The **app connector** advertises the two addresses that path needs. The VPC resolver is the only resolver that knows the private DNS mapping, and a client outside the VPC cannot reach it directly, so the query rides the connector. The endpoint ENI carries the object bytes.

## Policy File Example

Two edits to your tailnet policy file, one before `terraform apply` and one after.

### Before you apply

Terraform requests a device key carrying these tags. If nothing owns them, the apply fails when it creates the key.

```json
{
    "tagOwners": {
        "tag:example-infra":        ["autogroup:admin"],
        "tag:example-appconnector": ["autogroup:admin"],
    },
}
```

### After you apply

Terraform creates the split DNS entry and the device key. The app connector definition is the one piece it cannot create, because the provider has no resource for it and it lives in the policy file. The bucket domain and the routes are not known until the apply finishes, so this edit comes second.

Fill in `domains` from the `s3_domain` output and `routes` from the `s3_advertised_routes` output.

```json
{
    "nodeAttrs": [
        {
            // "target" must be "*". The "connectors" field scopes this to the
            // tagged device; the API rejects a tag in "target".
            "target": ["*"],
            "app": {
                "tailscale.com/app-connectors": [
                    {
                        "name":       "example-s3",
                        "connectors": ["tag:example-appconnector"],
                        "domains":    ["example-bucket.s3.us-west-2.amazonaws.com"],
                        // Routes declared here are implicitly approved.
                        "routes":     ["10.0.80.2/32", "10.0.80.47/32"],
                    },
                ],
            },
        },
    ],
}
```

## Considerations

- The app connector definition has to be added to your policy file by hand. The Tailscale provider has no app connector resource, and the only way to write `nodeAttrs` from Terraform is `tailscale_acl`, which replaces the entire policy file. The connector advertises no routes until you add it.
- The routes are declared in the `routes` field of the app connector definition rather than passed to `--advertise-routes`. Routes declared there are implicitly approved, so nothing needs approving in the admin console and no [Auto Approvers](https://tailscale.com/kb/1018/acls/#auto-approvers-for-routes-and-exit-nodes) entry is required.
- Only [virtual-hosted-style](https://docs.aws.amazon.com/AmazonS3/latest/userguide/VirtualHosting.html) requests take the private path. A path-style request uses the shared regional hostname, does not match the split DNS entry, and goes out publicly.
- The endpoint policy allows `s3:*` on this one bucket rather than just `s3:GetObject`. A client routing the bucket through the endpoint sends its control-plane calls the same way, and a read-only endpoint policy makes tooling such as the AWS CLI fail against the bucket.
- The connector must be in the same VPC as the endpoint. The ENI and the VPC resolver are only reachable from inside the VPC.
- `enable_dns_support` and `enable_dns_hostnames` must both be enabled on the VPC or the private DNS override does nothing. The VPC module used here enables both by default.

## To use

Follow the documentation to configure the Terraform providers:

- [Tailscale](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs)
- [AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Deploy

Add the `tagOwners` entries above to your policy file first, then:

```shell
terraform init
terraform apply
```

Add the app connector to your policy file, using these values:

```shell
terraform output s3_domain
terraform output s3_advertised_routes
```

Then check the path from a tailnet client:

```shell
# Resolves to the endpoint ENI, a private address.
dig +short "$(terraform output -raw s3_domain)"

# 200 through the connector, 403 from the public internet.
curl -sI "$(terraform output -raw s3_object_url)" | head -1
```

## To destroy

```shell
terraform destroy
```
