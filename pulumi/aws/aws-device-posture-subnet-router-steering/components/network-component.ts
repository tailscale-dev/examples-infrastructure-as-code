import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";
import * as awsx from "@pulumi/awsx";

export interface NetworkComponentArgs {
  vpcCidrBlock: string | undefined;

  publicSubnetCidrs?: string[] | undefined;
  privateSubnetCidrs?: string[] | undefined;

  numberOfAvailabilityZones?: number;
}

export class NetworkComponent extends pulumi.ComponentResource {
  public readonly vpc: awsx.ec2.Vpc;
  public readonly publicSecurityGroup: aws.ec2.SecurityGroup;
  public readonly privateSecurityGroup: aws.ec2.SecurityGroup;

  constructor(
    name: string,
    args: NetworkComponentArgs,
    opts?: pulumi.ComponentResourceOptions,
  ) {
    super("custom:network:NetworkComponent", name, {}, opts);

    const resourceOpts: pulumi.ResourceOptions = {
      parent: this,
      ...opts,
    };

    this.vpc = new awsx.ec2.Vpc(
      `${name}-vpc`,
      {
        cidrBlock: args.vpcCidrBlock,
        numberOfAvailabilityZones: args.numberOfAvailabilityZones ?? 2,
        subnetStrategy: awsx.ec2.SubnetAllocationStrategy.Auto,
        subnetSpecs: [
          {
            type: "Public",
            cidrBlocks: args.publicSubnetCidrs,
          },
          {
            type: "Private",
            cidrBlocks: args.privateSubnetCidrs,
          },
        ],
        enableDnsHostnames: true,
        enableDnsSupport: true,
      },
      resourceOpts,
    );

    // Public SG
    this.publicSecurityGroup = new aws.ec2.SecurityGroup(
      `${name}-public-sg`,
      {
        description: "Public Security Group",
        vpcId: this.vpc.vpc.id,
        egress: [
          {
            protocol: "-1",
            fromPort: 0,
            toPort: 0,
            cidrBlocks: ["0.0.0.0/0"],
          },
        ],
        ingress: [
          {
            protocol: "udp",
            fromPort: 41641,
            toPort: 41641,
            cidrBlocks: ["0.0.0.0/0"],
            description: "Tailscale",
          },
        ],
        tags: {
          Name: `${name}-public-sg`,
        },
      },
      resourceOpts,
    );

    // Private SG
    this.privateSecurityGroup = new aws.ec2.SecurityGroup(
      `${name}-private-sg`,
      {
        description: "Private Security Group",
        vpcId: this.vpc.vpc.id,
        egress: [
          {
            protocol: "-1",
            fromPort: 0,
            toPort: 0,
            cidrBlocks: ["0.0.0.0/0"],
          },
        ],
        ingress: [
          {
            protocol: "icmp",
            fromPort: -1,
            toPort: -1,
            securityGroups: [this.publicSecurityGroup.id],
          },
          {
            description: "Allow traceroute from Public SG",
            protocol: "udp",
            fromPort: 33434,
            toPort: 33554,
            securityGroups: [this.publicSecurityGroup.id],
          },
          {
            description: "HTTP Traffic from Public SG",
            protocol: "tcp",
            fromPort: 80,
            toPort: 80,
            securityGroups: [this.publicSecurityGroup.id],
          },
        ],
        tags: {
          Name: `${name}-private-sg`,
        },
      },
      resourceOpts,
    );

    this.registerOutputs({
      vpcId: this.vpc.vpc.id,
      publicSubnetIds: this.vpc.publicSubnetIds,
      privateSubnetIds: this.vpc.privateSubnetIds,
      publicSecurityGroupId: this.publicSecurityGroup.id,
      privateSecurityGroupId: this.privateSecurityGroup.id,
    });
  }
}
