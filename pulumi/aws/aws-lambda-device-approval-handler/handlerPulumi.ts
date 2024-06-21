import * as aws from "@pulumi/aws";
import * as handler from "./handler";


export const getPulumiHandler = (name: string) => {
    return new aws.lambda.CallbackFunction(name, {
        callback: async (ev: any, ctx) => {
            return handler.lambdaHandler(ev);
        },
    });
};
