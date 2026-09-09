# aws-lambda-device-approval-handler

This example creates the following:

- a API Gateway REST API
- a Lambda function to receive [Tailscale webhooks](https://tailscale.com/kb/1213/webhooks) and approve devices based on device details and attributes

## To use

Follow the documentation to configure the Pulumi providers:

- [AWS](https://www.pulumi.com/registry/packages/aws/installation-configuration/)

### Deploy

Create a [Tailscale OAuth Client](https://tailscale.com/kb/1215/oauth-clients#setting-up-an-oauth-client) with scope `all`. Provide the client ID and the client secret for the Lambda function with `pulumi config set ...` as shown below. Also set the `tailscale:` provider config keys. Pulumi uses these keys to configure the default Tailscale provider automatically.

```shell
pulumi stack init
pulumi config set tailscaleOauthClientId
pulumi config set tailscaleOauthClientSecret --secret
pulumi config set tailscale:oauthClientId
pulumi config set tailscale:oauthClientSecret --secret
pulumi up
```

`pulumi up` creates the Lambda function and API Gateway, then registers a Tailscale webhook that points at the API Gateway URL. The webhook subscribes to the `nodeNeedsApproval` event. Pulumi stores the webhook signing secret in the `webhookSecret` stack output.

## To destroy

```shell
pulumi down
```
