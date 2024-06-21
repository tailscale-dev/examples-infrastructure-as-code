import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';

interface TailnetEvent {
    timestamp: string;
    version: number;
    type: string;
    tailnet: string;
    message: string;
    data: any
}

export const lambdaHandler = async (ev: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    // TODO: https://tailscale.com/kb/1213/webhooks#verifying-an-event-signature
    try {
        let tailnetEvents: TailnetEvent[] = JSON.parse(ev.body!);
        tailnetEvents.forEach((event) => {
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
            body: JSON.stringify({ message: 'An error occurred.' }),
        };
    }
};

const nodeNeedsApprovalHandler = function (event: TailnetEvent) {
    console.log(`Handling event type [${event.type}]`);
}

const unhandledHandler = function (event: TailnetEvent) {
    console.log(`Skipping unhandled event type [${event.type}]`);
}

const eventFunctions = {
    "nodeNeedsApproval": nodeNeedsApprovalHandler,
};
