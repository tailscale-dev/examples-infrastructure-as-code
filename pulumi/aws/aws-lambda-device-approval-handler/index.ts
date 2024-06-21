import * as path from 'path';
import * as apigateway from "@pulumi/aws-apigateway";
import * as aws from "@pulumi/aws";

import * as handler from "./handlerPulumi";

const name = `example-${path.basename(process.cwd())}`;

const api = new apigateway.RestAPI(name, {
    stageName: "tailscale-device-approval",
    binaryMediaTypes: ["application/json"],
    routes: [
        {
            path: "/",
            method: "GET",
            eventHandler: new aws.lambda.CallbackFunction(name, {
                callback: async (ev: any, ctx) => {
                    console.log(`Not handling GET from ${ev.requestContext.identity.sourceIp}`);
                    return { statusCode: 500 };
                },
            }),
        },
        {
            path: "/",
            method: "POST",
            eventHandler: handler.getPulumiHandler(`${name}-fn`),
        },
    ],
});

export const url = api.url;
