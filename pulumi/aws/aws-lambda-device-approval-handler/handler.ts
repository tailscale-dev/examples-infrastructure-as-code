import { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";
import querystring = require("querystring"); // TODO: not necessary?

interface TailnetEvent {
    timestamp: string;
    version: number;
    type: string;
    tailnet: string;
    message: string;
    data: any
};

interface TailnetEventDeviceData {
    nodeID: string;
    deviceName: string;
    managedBy: string;
    actor: string;
    url: string;
};

interface ProcessingResult {
    event: TailnetEvent;
    result: "SUCCESS" | "ERROR" | "IGNORED";
    error: Error | null;
}

export async function lambdaHandler(ev: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
    // TODO: https://tailscale.com/kb/1213/webhooks#verifying-an-event-signature
    console.log(`Received event: ${JSON.stringify(ev)}`);
    let successCount = 0;
    let errorCount = 0;
    let ignoreCount = 0;
    try {
        let decodedBody = ev.body;
        if (ev.isBase64Encoded) {
            decodedBody = Buffer.from(ev.body!, 'base64').toString('utf8');
        }
        const tailnetEvents: TailnetEvent[] = JSON.parse(decodedBody!);
        const results: ProcessingResult[] = [];
        for (const event of tailnetEvents) {
            switch (event.type) { // https://tailscale.com/kb/1213/webhooks#events
                case "nodeNeedsApproval":
                    results.push(await nodeNeedsApprovalHandler(event));
                    break;
                default:
                    results.push(await unhandledHandler(event));
                    break;
            }
        }
        results.forEach(it => {
            switch (it.result) {
                case "SUCCESS":
                    successCount++;
                    break;
                case "ERROR":
                    errorCount++;
                    console.log(`Error processing event: ${it.error}`);
                    break;
                case "IGNORED":
                    ignoreCount++;
                    break;
            }
        });

        return generateResponseBody((errorCount > 0 ? 500 : 200), ev, successCount, errorCount, ignoreCount);
    } catch (err) {
        console.log(err);
        return generateResponseBody(500, ev, successCount, errorCount, ignoreCount);
    }
}

function generateResponseBody(statusCode: number, ev: APIGatewayProxyEvent, successCount: number, errorCount: number, ignoreCount: number): APIGatewayProxyResult {
    console.log(`success count: [${successCount}], error count: [${errorCount}], ignore count: [${ignoreCount}]`);
    return {
        statusCode: statusCode,
        body: JSON.stringify({
            message: (statusCode == 200 ? "ok" : "An error occurred."),
            // requestId: ev.requestContext.requestId, // TODO: This requestId doesn't match what's in the lambda logs.
            eventCounts: {
                success: successCount,
                ignored: ignoreCount,
                errors: errorCount,
            },
        }),
    };
}

async function unhandledHandler(event: TailnetEvent): Promise<ProcessingResult> {
    console.log(`Ignoring event type [${event.type}]`);
    return {
        event: event,
        result: "IGNORED",
    } as ProcessingResult;
}

async function nodeNeedsApprovalHandler(event: TailnetEvent): Promise<ProcessingResult> {
    try {
        console.log(`Handling event type [${event.type}]`);
        await approveDevice(event.data as TailnetEventDeviceData);
    }
    catch (err: any) {
        console.log(`Caught error [${err}]`);
        console.log(err.stack);
        return { result: "IGNORED", event: event, error: err, } as ProcessingResult;
    }
    return { result: "SUCCESS", event: event, } as ProcessingResult;
}

export const ENV_TAILSCALE_OAUTH_CLIENT_ID = "OAUTH_CLIENT_ID";
export const ENV_TAILSCALE_OAUTH_CLIENT_SECRET = "OAUTH_CLIENT_SECRET";
const TAILSCALE_CONTROL_URL = "https://login.tailscale.com";

// https://github.com/tailscale/tailscale/blob/main/publicapi/device.md#authorize-device
async function approveDevice(device: TailnetEventDeviceData): Promise<Error | null> {
    try {
        console.log(`Approving device [${device.nodeID}:${device.deviceName}]`);
        const data = await makeAuthenticatedPost(`${TAILSCALE_CONTROL_URL}/api/v2/device/${device.nodeID}/authorized`, JSON.stringify({ "authorized": true }));
        const json = await data.json();
        console.log(`device approval response [${JSON.stringify(json)}]`);
        const ok = await data.ok;
        if (!ok) {
            return Error(`Failed to approve device [${device.nodeID}:${device.deviceName}]`);
        }
    } catch (err: any) {
        console.log(`Caught error [${err}]`);
        console.log(err.stack);
        return err;
    }

    return null;
}

export async function getAccessToken(): Promise<any> {
    const oauthClientId = process.env[ENV_TAILSCALE_OAUTH_CLIENT_ID];
    const oauthClientSecret = process.env[ENV_TAILSCALE_OAUTH_CLIENT_SECRET];
    if (!oauthClientId || !oauthClientSecret) {
        throw new Error(`Missing required environment variables ${ENV_TAILSCALE_OAUTH_CLIENT_ID} and ${ENV_TAILSCALE_OAUTH_CLIENT_SECRET}. See https://tailscale.com/kb/1215/oauth-clients.`);
    }

    const data = querystring.stringify({
        client_id: oauthClientId,
        client_secret: oauthClientSecret,
    });

    const options: RequestInit = {
        method: "POST",
        headers: {
            "Content-Type": "application/x-www-form-urlencoded",
        },
        body: data,
    };

    // console.log(`getting access token`);
    return await httpsRequest(`${TAILSCALE_CONTROL_URL}/api/v2/oauth/token`, options);
}

const makeAuthenticatedPost = async function (url: string, body: string): Promise<Response> {
    const accessTokenResponse = await getAccessToken();
    const result = await accessTokenResponse.json();

    const options: RequestInit = {
        method: "POST",
        headers: {
            "Authorization": `Bearer ${result.access_token}`
        },
        body: body,
    };

    return await httpsRequest(url, options);
}

async function httpsRequest(url: string, options: any): Promise<Response> {
    console.log(`Making HTTP request to [${url}] with options [${JSON.stringify(options)}]`); // TODO: add verbose logging flag?
    return await fetch(url, options);
}
