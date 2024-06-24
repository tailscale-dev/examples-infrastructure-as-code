import * as apigateway from "@pulumi/aws-apigateway";
import * as path from 'path';
import * as handler from "./handlerPulumi";

const name = `example-${path.basename(process.cwd())}`;

const api = new apigateway.RestAPI(name, {
    stageName: "tailscale-device-approval",
    binaryMediaTypes: ["application/json"],
    routes: [
        {
            path: "/",
            method: "POST",
            eventHandler: handler.getPulumiHandler(`${name}-fn`),
        },
    ],
});

export const url = api.url;
