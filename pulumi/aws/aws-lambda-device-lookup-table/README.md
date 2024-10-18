# aws-lambda-device-lookup-table

This example creates the following:

- a API Gateway REST API
- a Lambda function to handle `nodeCreated` [Tailscale webhooks](https://tailscale.com/kb/1213/webhooks) and generate a CSV of device data in the form:

    ```csv
    Device ID, Device Name, Associated User or ACL Tags
    ```

## To use

### Customize

In its current form the Lambda function prints the generated CSV to `console.log(...)` and does not persist it anywhere. Modify [`handler.ts`](./handler.ts) to push the generated CSV to your SIEM or logging tool for use as a lookup table to augment Tailscale's network flow log data - e.g. [Sumo Logic's lookup tables](https://help.sumologic.com/docs/search/lookup-tables/), [Datadog's reference tables](https://docs.datadoghq.com/integrations/guide/reference-tables/), etc.

### Configure

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
