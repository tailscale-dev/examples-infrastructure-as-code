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

    console.log(`Received event: ${JSON.stringify(ev)}`);

    let successOrIgnoredCount = 0;
    let errorCount = 0;
    try {
        const tailnetEvents: TailnetEvent[] = JSON.parse(ev.body!);
        const errors = tailnetEvents.map((event): Error | null => {
            // https://tailscale.com/kb/1213/webhooks#events
            switch (event.type) {
                case "nodeNeedsApproval":
                    return nodeNeedsApprovalHandler(event);
                default:
                    return unhandledHandler(event);
            }
        });
        successOrIgnoredCount = errors.filter(er => er == null).length;
        errorCount = errors.filter(er => er != null).length;

        let statusCode = 200;
        if (errorCount > 0) {
            statusCode = 500;
        }
        console.log(`successfully processed or ignored count: [${successOrIgnoredCount}], error count: [${errorCount}]`);
        return generateResponseBody(statusCode, ev, successOrIgnoredCount, errorCount);
    } catch (err) {
        console.log(err);
        return generateResponseBody(500, ev, successOrIgnoredCount, errorCount);
    }
};

const generateResponseBody = function (statusCode: number, ev: APIGatewayProxyEvent, successOrIgnoredCount: number, errorCount: number): APIGatewayProxyResult {
    return {
        statusCode: statusCode,
        body: JSON.stringify({
            message: (statusCode == 200 ? "ok" : "An error occurred."),
            // requestId: ev.requestContext.requestId, // TODO: This requestId doesn't match what's in the lambda logs.
            eventCounts: {
                successOrIgnored: successOrIgnoredCount,
                error: errorCount,
            },
        }),
    };
}

const nodeNeedsApprovalHandler = function (event: TailnetEvent): Error | null {
    console.log(`Handling event type [${event.type}]`);
    return null;
    // console.log(`returning fake error`);
    // return new Error(`Fake error occurred for  [${event.type}]`);
}

const unhandledHandler = function (event: TailnetEvent): null {
    console.log(`Skipping unhandled event type [${event.type}]`);
    return null;
}
