import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";
import * as fs from "fs";
import * as tailscale from "@pulumi/tailscale";
import { TailscaleComponent } from "./components/tailscale-component";
import { NetworkComponent } from "./components/network-component";
import { getUbuntuLinuxAmi } from "./utils/utils";

const config = new pulumi.Config();
const owner = config.require("owner");
const vpcCidrBlock = config.get("vpcCidrBlock") || "10.0.0.0/16";
const privateSubnetCidrs = config.get("privateSubnetCidrs") || "10.0.1.0/24";
const publicSubnetCidrs = config.get("publicSubnetCidrs") || "10.0.101.0/24";
const privateInstanceIP = config.get("privateInstanceIP") || "10.0.1.25";

const tailscaleConfig = new pulumi.Config("tailscale");
tailscaleConfig.requireSecret("oauthClientSecret"); // Required for the provider
tailscaleConfig.require("oauthClientId"); // Required for the provider
tailscaleConfig.require("tailnet");

const tailscaleACL = new tailscale.Acl("tailnet-acl", {
  acl: fs.readFileSync("./acl.hujson", "utf8"),
  overwriteExistingContent: config.requireBoolean("overwriteExistingACL"), // Doing this to force you to be explicit about overwriting existing ACLs
});

const oauthClient = new tailscale.OauthClient(`${owner}-tailnet-oauth-client`, {
  scopes: ["auth_keys"],
  description: `Managed by Pulumi Project-${pulumi.getProject()}`,
  tags: ["tag:parent-tag"], // Parent Tag which owns all sub-tags
});

const regionData: { region: aws.Region; primary: string; secondary: string }[] =
  [
    { region: "us-west-2", primary: "pdx", secondary: "eug" },
    { region: "us-east-2", primary: "cle", secondary: "cvg" },
  ];

for (const record of regionData) {
  const provider = new aws.Provider(`aws-provider-${record.region}`, {
    region: record.region,
    defaultTags: {
      tags: {
        Owner: owner,
      },
    },
  });

  const networkComponent = new NetworkComponent(
    `${owner}-network-${record.region}`,
    {
      vpcCidrBlock: vpcCidrBlock,
      privateSubnetCidrs: [privateSubnetCidrs],
      publicSubnetCidrs: [publicSubnetCidrs],
      numberOfAvailabilityZones: 1,
    },
    { provider: provider },
  );

  const tailscaleOAuthKeyString: pulumi.Output<string> = pulumi.interpolate`${oauthClient.key}?ephemeral=true&preauthorized=true`;
  new TailscaleComponent(
    `${owner}-subnet-router-${record.region}-${record.primary}`,
    {
      ami: getUbuntuLinuxAmi(provider).id,
      vpcSecurityGroupIds: [networkComponent.publicSecurityGroup.id],
      subnetId: networkComponent.vpc.publicSubnetIds[0],
      instanceType: "t4g.small", // Not recommended for production, see https://tailscale.com/kb/1296/aws-reference-architecture#recommended-instance-sizing
      tailscaleArgs: {
        authKey: tailscaleOAuthKeyString,
        ssh: true,
        advertiseRoutes: [vpcCidrBlock],
        advertiseTags: [`tag:${record.primary}`],
      },
    },
    {
      dependsOn: [tailscaleACL],
      provider: provider,
    },
  );

  new TailscaleComponent(
    `${owner}-subnet-router-${record.region}-${record.secondary}`,
    {
      ami: getUbuntuLinuxAmi(provider).id,
      vpcSecurityGroupIds: [networkComponent.publicSecurityGroup.id],
      subnetId: networkComponent.vpc.publicSubnetIds[0],
      instanceType: "t4g.small", // Not recommended for production, see https://tailscale.com/kb/1296/aws-reference-architecture#recommended-instance-sizing
      tailscaleArgs: {
        authKey: tailscaleOAuthKeyString,
        ssh: true,
        advertiseRoutes: [vpcCidrBlock],
        advertiseTags: [`tag:${record.secondary}`],
      },
    },
    {
      dependsOn: [tailscaleACL],
      provider: provider,
    },
  );

  const privateInstanceName = `${owner}-private-instance-${record.region}`;
  new aws.ec2.Instance(
    privateInstanceName,
    {
      subnetId: networkComponent.vpc.privateSubnetIds[0],
      instanceType: "t4g.nano",
      vpcSecurityGroupIds: [networkComponent.privateSecurityGroup.id],
      ami: getUbuntuLinuxAmi(provider).id,
      privateIp: privateInstanceIP,
      tags: {
        Name: privateInstanceName,
      },
    },
    {
      provider: provider,
      replaceOnChanges: ["userData"],
      deleteBeforeReplace: true,
    },
  );
}

export const testCommand = `tailscale ping ${privateInstanceIP}`;
