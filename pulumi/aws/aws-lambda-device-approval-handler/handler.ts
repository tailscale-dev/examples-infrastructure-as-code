import * as aws from "@pulumi/aws";

interface TailscaleEvent {
    timestamp: string;
    version: number;
    type: string;
    tailnet: string;
    message: string;
    data: any
}

export const getHandler = (name: string) => {
    return new aws.lambda.CallbackFunction(name, {
        callback: async (ev: any, ctx) => {
            // TODO: https://tailscale.com/kb/1213/webhooks#verifying-an-event-signature
            let events: TailscaleEvent[] = JSON.parse(ev.body);
            events.forEach((event) => {
                switch (event.type) {
                    case "nodeNeedsApproval":
                        eventFunctions.nodeNeedsApproval(event);
                        break;
                    default:
                        unhandledHandler(event);
                }
            });
            return {
                statusCode: 204,
            };
        },
    });
};

const nodeNeedsApprovalHandler = function (event: TailscaleEvent) {
    console.log(`Handling event type [${event.type}]`);
}

const unhandledHandler = function (event: TailscaleEvent) {
    console.log(`Skipping unhandled event type [${event.type}]`);
}

const eventFunctions = {
    "nodeNeedsApproval": nodeNeedsApprovalHandler,
};
