import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";
import * as apigateway from "@pulumi/aws-apigateway";
import * as path from "path";

import * as handler from "./handler";

const name = `example-${path.basename(process.cwd())}`;
const pulumiConfig = new pulumi.Config();

const api = new apigateway.RestAPI(name, {
    stageName: "tailscale-device-approval",
    binaryMediaTypes: ["application/json"],
    routes: [
        {
            path: "/",
            method: "POST",
            eventHandler: new aws.lambda.CallbackFunction(`${name}-fn`, {
                environment: {
                    variables: {
                        [handler.ENV_TAILSCALE_OAUTH_CLIENT_ID]: pulumiConfig.require("tailscaleOauthClientId"),
                        [handler.ENV_TAILSCALE_OAUTH_CLIENT_SECRET]: pulumiConfig.requireSecret("tailscaleOauthClientSecret"),
                    },
                },
                runtime: "nodejs20.x",
                callback: async (ev: any, ctx) => {
                    return handler.lambdaHandler(ev);
                },
            }),
        },
    ],
});

export const url = api.url;
