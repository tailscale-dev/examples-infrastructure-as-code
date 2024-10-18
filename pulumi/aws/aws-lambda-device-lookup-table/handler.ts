import { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";

export async function lambdaHandler(ev: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> {
    // TODO: https://tailscale.com/kb/1213/webhooks#verifying-an-event-signature
    // console.log(`Received event: ${JSON.stringify(ev)}`);

    let processedCount = 0;
    let ignoredCount = 0;
    let erroredCount = 0;
    try {
        let decodedBody = ev.body;
        if (ev.isBase64Encoded) {
            decodedBody = Buffer.from(ev.body!, "base64").toString("utf8");
        }
        const tailnetEvents: TailnetEvent[] = JSON.parse(decodedBody!);
        const results: ProcessingResult[] = [];
        for (const event of tailnetEvents) {
            try {
                switch (event.type) { // https://tailscale.com/kb/1213/webhooks#events
                    case "nodeCreated":
                        results.push(await nodeCreatedHandler(event));
                        break;
                    default:
                        results.push(await unhandledHandler(event));
                        break;
                }
            }
            catch (err: any) {
                results.push({ event: event, result: "ERROR", error: err, } as ProcessingResult);
            }
        }
        results.forEach(it => {
            switch (it.result) {
                case "SUCCESS":
                    processedCount++;
                    break;
                case "IGNORED":
                    ignoredCount++;
                    break;
                case "ERROR":
                    console.log(`Error processing event [${JSON.stringify(it.event)}]: ${it.error}`);
                    erroredCount++;
                    break;
            }
        });

        return generateResponseBody((erroredCount > 0 ? 500 : 200), ev, processedCount, erroredCount, ignoredCount);
    } catch (err) {
        console.log(err);
        return generateResponseBody(500, ev, processedCount, erroredCount, ignoredCount);
    }
}

function generateResponseBody(statusCode: number, ev: APIGatewayProxyEvent, processedCount: number, erroredCount: number, ignoredCount: number): APIGatewayProxyResult {
    const result = {
        statusCode: statusCode,
        body: JSON.stringify({
            message: (statusCode == 200 ? "ok" : "An error occurred."),
            eventResults: {
                processed: processedCount,
                errored: erroredCount,
                ignored: ignoredCount,
            },
        }),
    };
    console.log(`returning response: ${JSON.stringify(result)}`);
    return result
}

async function unhandledHandler(event: TailnetEvent): Promise<ProcessingResult> {
    console.log(`Ignoring event type [${event.type}]`);
    return { event: event, result: "IGNORED", } as ProcessingResult;
}

async function nodeCreatedHandler(event: TailnetEvent): Promise<ProcessingResult> {
    try {
        console.log(`Handling event type [${event.type}]`);

        const eventData = event.data as TailnetEventDeviceData;

        const devicesResponse = await listTailnetDevices(eventData);
        if (!devicesResponse.ok) {
            throw new Error(`Failed to list tailnet devices, response status [${devicesResponse.status}]`);
        }

        const deviceCSV = generateDeviceCSV(devicesResponse);
        console.log(`Devices CSV:\n${deviceCSV}`); // TODO: persist to SIEM or Logging service

        return { event: event, result: "SUCCESS", } as ProcessingResult;
    } catch (err: any) {
        return { event: event, result: "ERROR", error: err, } as ProcessingResult;
    }
}

export const ENV_TAILSCALE_OAUTH_CLIENT_ID = "OAUTH_CLIENT_ID";
export const ENV_TAILSCALE_OAUTH_CLIENT_SECRET = "OAUTH_CLIENT_SECRET";
const TAILSCALE_CONTROL_URL = "https://login.tailscale.com";

function parseTailnet(domain: string): string | null {
    const regex = /^[^.]+\.(.+\.ts\.net)$/;
    const match = domain.match(regex);
    return match ? match[1] : null;
}

async function generateDeviceCSV(devicesResponse: Response): Promise<string> {
    const devicesResponseJson = await devicesResponse.json();

    let devicesCsv = "";
    devicesResponseJson["devices"].forEach((device: any) => {
        devicesCsv += `${device.nodeId},${device.name},${device.user || device.tags}\n`;
    });

    return devicesCsv
}

// https://tailscale.com/api#tag/devices/GET/tailnet/{tailnet}/devices
async function listTailnetDevices(event: TailnetEventDeviceData): Promise<Response> {
    const tailnet = parseTailnet(event.deviceName);
    console.log(`List tailnet devices for [${tailnet}]`);
    const data = await makeAuthenticatedRequest("GET", `${TAILSCALE_CONTROL_URL}/api/v2/tailnet/${tailnet}/devices`);
    return data;
}

// https://tailscale.com/kb/1215/oauth-clients
export async function getAccessToken(): Promise<Response> {
    const oauthClientId = process.env[ENV_TAILSCALE_OAUTH_CLIENT_ID];
    const oauthClientSecret = process.env[ENV_TAILSCALE_OAUTH_CLIENT_SECRET];
    if (!oauthClientId || !oauthClientSecret) {
        throw new Error(`Missing required environment variables [${ENV_TAILSCALE_OAUTH_CLIENT_ID}] and [${ENV_TAILSCALE_OAUTH_CLIENT_SECRET}]. See https://tailscale.com/kb/1215/oauth-clients.`);
    }

    const options: RequestInit = {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: `client_id=${oauthClientId}&client_secret=${oauthClientSecret}`,
    };

    // console.log(`getting access token`);
    const data = await httpsRequest(`${TAILSCALE_CONTROL_URL}/api/v2/oauth/token`, options);
    if (!data.ok) {
        throw new Error(`Failed to get an access token.`);
    }
    return data;
}

const makeAuthenticatedRequest = async function (method: "GET" | "POST", url: string, body?: string): Promise<Response> {
    const accessTokenResponse = await getAccessToken();
    const result = await accessTokenResponse.json();

    const options: RequestInit = {
        method: method,
        headers: { "Authorization": `Bearer ${result.access_token}` },
        body: body,
    };

    return await httpsRequest(url, options);
}

async function httpsRequest(url: string, options: any): Promise<Response> {
    // console.log(`Making HTTP request to [${url}] with options [${JSON.stringify(options)}]`);
    return await fetch(url, options);
}

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
    error?: Error;
};
