locals {
  routes_file_s3_basepath = "s3://${aws_s3_bucket.routes.bucket}"
  routes_file_s3_instance_prefix = "tailscale-appconnector-routes-aws"

  routes_persistence_script = <<-EOT
    #!/bin/bash

    set -e

    apt-get -qq update
    apt-get -yqq install jq
    apt-get -yqq install awscli

    SCRIPT_PATH=/root/tailscale-persist-appconnector-routes.sh

    cat << EOF > $SCRIPT_PATH
    #!/bin/bash

    AWS_TOKEN=\`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"\`
    AWS_ZONE_ID=\`curl -H "X-aws-ec2-metadata-token: \$AWS_TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone-id\`
    AWS_AMI_LAUNCH_INDEX=\`curl -H "X-aws-ec2-metadata-token: \$AWS_TOKEN" http://169.254.169.254/latest/meta-data/ami-launch-index\`
    FILENAME=\$AWS_ZONE_ID/\$AWS_AMI_LAUNCH_INDEX.txt

    echo -n \`date -u +"%Y-%m-%dT%H:%M:%SZ"\`': '

    # skip the first two lines which are the device's own tailscale addresses
    tailscale status --json | jq -r .Self.AllowedIPs[] | tail -n +3 > tailscale-advertise-routes-export.txt

    aws s3 cp \
      tailscale-advertise-routes-export.txt \
      ${local.routes_file_s3_basepath}/${local.routes_file_s3_instance_prefix}/\$FILENAME

    EOF

    chmod +x $SCRIPT_PATH

    crontab<<EOF
    */1 * * * * $SCRIPT_PATH >> /root/tailscale-persist-appconnector-routes.log
    EOF

    EOT
}
