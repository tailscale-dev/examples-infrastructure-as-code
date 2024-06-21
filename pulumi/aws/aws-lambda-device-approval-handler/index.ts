import * as path from 'path';
import * as apigateway from "@pulumi/aws-apigateway";
import * as aws from "@pulumi/aws";

import * as handler from "./handler";

const name = `example-${path.basename(process.cwd())}`;

// const f = new aws.lambda.CallbackFunction(name, {
//     callback: async (ev, ctx) => {
//         console.log(JSON.stringify(ev));
//         return {
//             statusCode: 200,
//             body: "goodbye",
//         };
//     },
// });

const api = new apigateway.RestAPI(name, {
    stageName: "tailscale-device-approval",
    binaryMediaTypes: ["application/json"],
    routes: [
        {
            path: "/",
            method: "GET",
            eventHandler: new aws.lambda.CallbackFunction(name, {
                callback: async (ev, ctx) => {
                    console.log(JSON.stringify(ev));
                    return {
                        statusCode: 500,
                    };
                },
            }),
        },
        {
            path: "/",
            method: "POST",
            eventHandler: handler.getHandler(`${name}-fn`),
        },
    ],
});

// TODO: re-enable once we establish why `api.api.id` is coming back as undefined

// const apiKey = new aws.apigateway.ApiKey("api-key");
// const usagePlan = new aws.apigateway.UsagePlan("usage-plan", {
//   apiStages: [
//     {
//       apiId: api.api.id,
//       stage: api.stage.stageName,
//     },
//   ],
// });

// new aws.apigateway.UsagePlanKey("usage-plan-key", {
//   keyId: apiKey.id,
//   keyType: "API_KEY",
//   usagePlanId: usagePlan.id,
// });

export const url = api.url;

// // Create an API endpoint.
// const endpoint = new awsx.apigateway.API("hello-world", {
//   routes: [
//     // {
//     //   path: "/{route+}",
//     //   method: "GET",
//     //   // Functions can be imported from other modules
//     //   eventHandler: handler,
//     // },
//     {
//       path: "/{route+}",
//       method: "POST",
//       // Functions can be created inline
//       eventHandler: (event) => {
//         console.log("Inline event handler");
//         console.log(event);
//       },
//     },
//     // {
//     //   path: "/{route+}",
//     //   method: "DELETE",
//     //   // Functions can be created inline
//     //   eventHandler: (event) => {
//     //     console.log("Inline delete event handler");
//     //     console.log(event);
//     //   },
//     // },
//   ],
// });

// export const endpointUrl = endpoint.url;
