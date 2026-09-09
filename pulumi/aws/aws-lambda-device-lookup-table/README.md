# aws-lambda-device-lookup-table

This example creates the following:

- a API Gateway REST API
- a Lambda function to handle `nodeCreated` [Tailscale webhooks](https://tailscale.com/kb/1213/webhooks) and generate a CSV of device data in the form:

    ```csv
    Device ID, Device Name, Associated User or ACL Tags
    ```

- a Tailscale [webhook](https://tailscale.com/kb/1213/webhooks) that sends `nodeCreated` events to the deployed Lambda's API Gateway URL

## To use

### Customize

In its current form the Lambda function prints the generated CSV to `console.log(...)` and does not persist it anywhere. Modify [`handler.ts`](./handler.ts) to push the generated CSV to your SIEM or logging tool for use as a lookup table to augment Tailscale's network flow log data - e.g. [Sumo Logic's lookup tables](https://help.sumologic.com/docs/search/lookup-tables/), [Datadog's reference tables](https://docs.datadoghq.com/integrations/guide/reference-tables/), etc.

### Configure

Follow the documentation to configure the Pulumi providers:

- [AWS](https://www.pulumi.com/registry/packages/aws/installation-configuration/)
- [Tailscale](https://www.pulumi.com/registry/packages/tailscale/installation-configuration/) — set the `TAILSCALE_OAUTH_CLIENT_ID` / `TAILSCALE_OAUTH_CLIENT_SECRET` environment variables before you run `pulumi up`. Pulumi uses these to authenticate the Tailscale provider that manages the webhook.

### Deploy

Create a [Tailscale OAuth Client](https://tailscale.com/kb/1215/oauth-clients#setting-up-an-oauth-client) with scope `all`. Set the client ID and client secret for the Lambda function with `pulumi config set ...`, and export the same values as environment variables for the Tailscale provider, as shown below.

```shell
pulumi stack init
pulumi config set tailscaleOauthClientId
pulumi config set tailscaleOauthClientSecret --secret
pulumi up
```

`pulumi up` creates the Lambda function and API Gateway, then registers the Tailscale webhook that points at the API Gateway URL.

### Outputs

| Output | Description |
| --- | --- |
| `url` | The API Gateway invoke URL. This is also the endpoint the Tailscale webhook is configured to call. |
| `lambdaFunctionName` | The name of the deployed Lambda function, for finding it in the AWS console or `aws logs`. |
| `webhookSecret` | The secret Tailscale generates when the webhook is created, for verifying the `Tailscale-Webhook-Signature` header as described in [Verifying an event signature](https://tailscale.com/kb/1213/webhooks#verifying-an-event-signature) (see the `TODO` in [`handler.ts`](./handler.ts)). This output is marked secret, so use `pulumi stack output webhookSecret --show-secrets` to view it. |

## To destroy

```shell
pulumi down
```
