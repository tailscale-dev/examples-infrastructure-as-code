import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';

interface TailscaleEvent {
    timestamp: string;
    version: number;
    type: string;
    tailnet: string;
    message: string;
    data: any
}

export const lambdaHandler = async (ev: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    try {
        // TODO: https://tailscale.com/kb/1213/webhooks#verifying-an-event-signature
        let events: TailscaleEvent[] = JSON.parse(ev.body!);
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
            body: JSON.stringify({ message: "ok" }),
        };
    } catch (err) {
        console.log(err);
        return {
            statusCode: 500,
            body: JSON.stringify({
                message: 'some error happened',
            }),
        };
    }
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
