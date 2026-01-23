import * as aws from "@pulumi/aws";

export function getUbuntuLinuxAmi(provider: aws.Provider) {
  return aws.ec2.getAmiOutput(
    {
      owners: ["amazon"],
      mostRecent: true,
      filters: [
        {
          name: "architecture",
          values: ["arm64"],
        },
        {
          name: "name",
          values: ["ubuntu/images/*ubuntu-noble-24.04-*"],
        },
        {
          name: "virtualization-type",
          values: ["hvm"],
        },
      ],
    },
    { provider: provider },
  );
}
