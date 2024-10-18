# aws-lambda-device-approval-handler

This example creates the following:

- a API Gateway REST API
- a Lambda function to receive [Tailscale webhooks](https://tailscale.com/kb/1213/webhooks) and approve devices based on device details and attributes

## To use

Follow the documentation to configure the Pulumi providers:

- [AWS](https://www.pulumi.com/registry/packages/aws/installation-configuration/)

### Deploy

Create a [Tailscale OAuth Client](https://tailscale.com/kb/1215/oauth-clients#setting-up-an-oauth-client) with scope `all` and provide the client ID and client secret with `pulumi config set ...` as shown below.

```shell
pulumi stack init
pulumi config set tailscaleOauthClientId
pulumi config set tailscaleOauthClientSecret --secret
pulumi up
```

## To destroy

```shell
pulumi down
```
