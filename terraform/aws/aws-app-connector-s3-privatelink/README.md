# aws-app-connector-s3-privatelink

> :information_source: This example is intended for users who want tailnet clients to reach **one specific S3 bucket** over a private path, while every other bucket and all other web traffic continues to go out over the public internet as before.

An app connector pointed at a public S3 endpoint advertises whatever that endpoint resolves to. S3's regional endpoints are large shared address pools that rotate, so the advertised route set grows without bound and never settles. This example gives the bucket a stable private address first, using an S3 interface VPC endpoint (AWS PrivateLink), and then advertises that one address. The connector's route set is a fixed pair instead of a moving target.

This example creates the following:

- a VPC and related resources including a NAT Gateway
- a private S3 bucket with one object, readable only through the VPC endpoint
- an S3 interface VPC endpoint (AWS PrivateLink) with private DNS, scoped by endpoint policy to that one bucket
- an EC2 instance running Tailscale as an app connector, advertising the VPC resolver and the endpoint ENI
- a Tailscale split DNS entry mapping the bucket's regional domain to the VPC resolver
- a Tailnet device key to authenticate the Tailscale device

## How the pieces fit

Three things have to line up for a single bucket to go private:

1. **The interface endpoint gives the bucket a private address.** With `private_dns_enabled` and `private_dns_only_for_inbound_resolver_endpoint = false`, resolving the bucket's regional domain from inside the VPC returns the endpoint's ENI address rather than a public S3 address.

2. **Split DNS sends only that one name to the VPC resolver.** The split DNS domain is the exact bucket FQDN (`<bucket>.s3.<region>.amazonaws.com`), not `s3.<region>.amazonaws.com`. Split DNS matches a domain and its subdomains, not its siblings, so other buckets in the same region never match, resolve publicly, and never involve the connector.

3. **The connector advertises the two addresses that path needs.** The VPC resolver (VPC base address + 2) is the only resolver that knows the endpoint's private DNS mapping, and a client outside the VPC cannot reach it directly, so its query has to ride the connector. The endpoint ENI carries the object bytes. The connector SNATs both, so they arrive as ordinary in-VPC traffic.

The instance is registered as an app connector for the bucket domain, which is what lets you write access rules against the domain name. Its routes are advertised explicitly rather than left to discovery: split DNS means discovery would resolve to the same ENI address anyway, and declaring them keeps the advertised set fixed and readable.

## Policy File Example

```json
{
    "tagOwners": {
        "tag:example-infra":        ["autogroup:admin"],
        "tag:example-appconnector": ["autogroup:admin"],
    },

    "autoApprovers": {
        "routes": {
            "0.0.0.0/0": ["tag:example-appconnector"],
        },
    },

    "nodeAttrs": [
        {
            // "target" must be "*". The "connectors" field is what scopes this
            // to the tagged device; the API rejects a tag in "target".
            "target": ["*"],
            "app": {
                "tailscale.com/app-connectors": [
                    {
                        "name":       "example-s3",
                        "connectors": ["tag:example-appconnector"],
                        // Replace with the "s3_domain" output after applying.
                        "domains":    ["example-bucket.s3.us-west-2.amazonaws.com"],
                    },
                ],
            },
        },
    ],
}
```

## Considerations

- The `domains` list in the app connector definition contains the bucket's regional domain, which is not known until after `terraform apply`. Apply first, then take the `s3_domain` output and add it to your policy file.
- Any advertised routes must still be approved in the Tailscale Admin Console. The policy above uses [Auto Approvers for routes](https://tailscale.com/kb/1018/acls/#auto-approvers-for-routes-and-exit-nodes) instead; narrow the auto-approved prefix if a blanket `0.0.0.0/0` is broader than you want.
- Only [virtual-hosted-style](https://docs.aws.amazon.com/AmazonS3/latest/userguide/VirtualHosting.html) requests (`https://<bucket>.s3.<region>.amazonaws.com/<key>`) take the private path. A path-style request uses the shared regional hostname, which does not match the split DNS entry and goes out publicly.
- The bucket policy grants reads only when `aws:SourceVpce` matches the endpoint, so a request from the public internet gets a 403. That condition is what keeps the grant non-public and acceptable under S3 Block Public Access.
- The endpoint policy allows `s3:*` on this one bucket rather than just `s3:GetObject`. A client whose split DNS routes the bucket through the endpoint sends its control-plane calls the same way, and a read-only endpoint policy causes tooling such as the AWS CLI to fail against the bucket. The bucket ARN in `Resource` is what keeps the scope narrow.
- The connector must live in the same VPC as the endpoint. The ENI and the VPC resolver are reachable only from inside the VPC.
- `enable_dns_support` and `enable_dns_hostnames` must both be enabled on the VPC or the endpoint's private DNS override does nothing. The VPC module used here enables both by default.

## To use

Follow the documentation to configure the Terraform providers:

- [Tailscale](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs)
- [AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Deploy

```shell
terraform init
terraform apply
```

Add the `s3_domain` output to the app connector definition in your policy file, then confirm the private path from a tailnet client:

```shell
# Resolves to the endpoint ENI (a private address), not a public S3 address.
dig +short "$(terraform output -raw s3_domain)"

# 200 from a tailnet client using the connector, 403 from the public internet.
curl -sI "$(terraform output -raw s3_object_url)" | head -1
```

## To destroy

```shell
terraform destroy
```
