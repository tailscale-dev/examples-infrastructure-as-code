import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";

import * as handler from "./handler";

const pulumiConfig = new pulumi.Config();

export const getPulumiHandler = (name: string) => {
    return new aws.lambda.CallbackFunction(name, {
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
    });
};
