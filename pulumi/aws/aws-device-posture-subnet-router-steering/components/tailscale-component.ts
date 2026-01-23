import * as aws from "@pulumi/aws";
import * as pulumi from "@pulumi/pulumi";
import * as tailscalecloudinit from "@pulumi/tailscale_cloudinit_config";
import * as inputs from "@pulumi/aws/types/input";

interface TailscaleArgs {
  ssh?: boolean;
  authKey: pulumi.Input<string>;
  advertiseRoutes?: string[];
  advertiseExitNode?: boolean;
  advertiseConnector?: boolean;
  acceptDNS?: boolean;
  acceptRoutes?: boolean;
  relayServerPort?: number;
  advertiseTags?: string[];
}

export interface TailscaleComponentArgs {
  subnetId: pulumi.Input<string>;
  vpcSecurityGroupIds?: pulumi.Input<pulumi.Input<string>[]>;
  ami: pulumi.Input<string>;
  keyName?: aws.ec2.KeyPair | undefined;
  instanceType?: pulumi.Input<aws.ec2.InstanceType>;
  privateIP?: pulumi.Input<string>;
  rootBlockDevice?: pulumi.Input<inputs.ec2.InstanceRootBlockDevice>;
  tags?: pulumi.Input<{ [key: string]: pulumi.Input<string> }>;

  tailscaleArgs: TailscaleArgs;
  additionalParts?: pulumi.Input<
    pulumi.Input<tailscalecloudinit.types.input.AdditionalPartsArgs>[]
  >;
}

export class TailscaleComponent extends pulumi.ComponentResource {
  public readonly instance: aws.ec2.Instance;

  constructor(
    name: string,
    args: TailscaleComponentArgs,
    opts?: pulumi.ComponentResourceOptions,
  ) {
    super("custom:resource:TailscaleComponent", name, {}, opts);
    
    const tailscaleCloudinit = new tailscalecloudinit.Module(
      `${name}-tailscale-cloudinit`,
      {
        auth_key: args.tailscaleArgs?.authKey,
        hostname: name,
        advertise_tags: args.tailscaleArgs?.advertiseTags,
        enable_ssh: args.tailscaleArgs?.ssh,
        advertise_connector: args.tailscaleArgs?.advertiseConnector,
        advertise_exit_node: args.tailscaleArgs?.advertiseExitNode,
        advertise_routes: args.tailscaleArgs?.advertiseRoutes,
        accept_dns: args.tailscaleArgs?.acceptDNS,
        accept_routes: args.tailscaleArgs?.acceptRoutes,
        relay_server_port: args.tailscaleArgs?.relayServerPort,
        additional_parts: args.additionalParts,
      },
      { parent: this },
    ).rendered as pulumi.Output<string>;
    
    const combinedTags = { Name: name, ...args.tags };

    this.instance = new aws.ec2.Instance(
      `${name}-ts`,
      {
        subnetId: args.subnetId,
        instanceType: args.instanceType || "t4g.nano",
        vpcSecurityGroupIds: args.vpcSecurityGroupIds,
        ami: args.ami,
        userDataBase64: pulumi.secret(tailscaleCloudinit),
        rootBlockDevice: args.rootBlockDevice,
        keyName: args.keyName?.keyName,
        privateIp: args.privateIP,
        tags: combinedTags,
      },
      {
        provider: opts?.provider,
        parent: this,
        replaceOnChanges: ["userData", "userDataBase64", "instanceType"],
      },
    );
  }
}
