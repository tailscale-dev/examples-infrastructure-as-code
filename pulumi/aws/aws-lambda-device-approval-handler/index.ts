import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";
import * as apigateway from "@pulumi/aws-apigateway";
import * as tailscale from "@pulumi/tailscale";
import * as path from "path";

import * as handler from "./handler";

const name = `example-${path.basename(process.cwd())}`;
const pulumiConfig = new pulumi.Config();
const tailscaleOauthClientId = pulumiConfig.require("tailscaleOauthClientId");
const tailscaleOauthClientSecret = pulumiConfig.requireSecret("tailscaleOauthClientSecret");

const fn = new aws.lambda.CallbackFunction(`${name}-fn`, {
    environment: {
        variables: {
            [handler.ENV_TAILSCALE_OAUTH_CLIENT_ID]: tailscaleOauthClientId,
            [handler.ENV_TAILSCALE_OAUTH_CLIENT_SECRET]: tailscaleOauthClientSecret,
        },
    },
    runtime: "nodejs20.x",
    callback: async (ev: any, ctx) => {
        return handler.lambdaHandler(ev);
    },
});

const api = new apigateway.RestAPI(name, {
    stageName: `${name}`,
    binaryMediaTypes: ["application/json"],
    routes: [
        {
            path: "/",
            method: "POST",
            eventHandler: fn,
        },
    ],
});

export const url = api.url;
export const lambdaFunctionName = fn.name;

const webhook = new tailscale.Webhook(`${name}-webhook`, {
    endpointUrl: api.url,
    subscriptions: ["nodeNeedsApproval"],
});

// Only set at creation. Store it if you plan to verify webhook signatures in the handler.
export const webhookSecret = pulumi.secret(webhook.secret);
