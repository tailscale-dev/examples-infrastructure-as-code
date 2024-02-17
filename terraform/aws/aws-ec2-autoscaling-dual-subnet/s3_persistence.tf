locals {
  routes_file_s3_basepath = "s3://${aws_s3_bucket.routes.bucket}"
  app_name = "aws"
  routes_file_s3_instance_prefix = "tailscale-appconnector-routes/app-${local.app_name}"

  script_routes_restore = <<-EOT
    #!/bin/bash

    set -e

    apt-get -qq update
    apt-get -yqq install jq
    apt-get -yqq install awscli

    SCRIPT_PATH=/root/tailscale-appconnector-routes-restore.sh
    ROUTES_TO_RESTORE_DIR=/root/tailscale-appconnector-routes-to-restore-${local.app_name}/
    mkdir -p $ROUTES_TO_RESTORE_DIR

    # save to a file so we can re-run in the future if neeeded
    cat << EOF > $SCRIPT_PATH
    #!/bin/bash

    set -e

    ROUTES_TO_RESTORE_DIR=$ROUTES_TO_RESTORE_DIR

    AWS_TOKEN=\`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"\`
    AWS_ZONE_ID=\`curl -s -H "X-aws-ec2-metadata-token: \$AWS_TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone-id\`
    FILENAME=\$AWS_ZONE_ID/

    # skip the first two lines which are the device's own tailscale addresses
    tailscale status --json | jq -r .Self.AllowedIPs[] | tail -n +3 > \$ROUTES_TO_RESTORE_DIR/initial-routes-from-userdata.txt

    aws s3 cp \
      --recursive \
      ${local.routes_file_s3_basepath}/${local.routes_file_s3_instance_prefix}/\$FILENAME \
      \$ROUTES_TO_RESTORE_DIR

    ROUTES=\$(cat \$ROUTES_TO_RESTORE_DIR/* | tr '\n' ',' | sed 's/[,]$//')
    tailscale set --advertise-routes=\$ROUTES

    EOF

    chmod +x $SCRIPT_PATH

    sh ./$SCRIPT_PATH

  EOT

  script_routes_persist = <<-EOT
    #!/bin/bash

    set -e

    apt-get -qq update
    apt-get -yqq install jq
    apt-get -yqq install awscli

    SCRIPT_PATH=/root/tailscale-appconnector-routes-persist.sh

    cat << EOF > $SCRIPT_PATH
    #!/bin/bash

    AWS_TOKEN=\`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"\`
    AWS_ZONE_ID=\`curl -H "X-aws-ec2-metadata-token: \$AWS_TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone-id\`
    AWS_AMI_LAUNCH_INDEX=\`curl -H "X-aws-ec2-metadata-token: \$AWS_TOKEN" http://169.254.169.254/latest/meta-data/ami-launch-index\`
    FILENAME=\$AWS_ZONE_ID/ami-launch-index-\$AWS_AMI_LAUNCH_INDEX.txt

    echo -n \`date -u +"%Y-%m-%dT%H:%M:%SZ"\`': '

    # skip the first two lines which are the device's own tailscale addresses
    tailscale status --json | jq -r .Self.AllowedIPs[] | tail -n +3 | \
      aws s3 cp \
      - \
      ${local.routes_file_s3_basepath}/${local.routes_file_s3_instance_prefix}/\$FILENAME

    EOF

    chmod +x $SCRIPT_PATH

    crontab << EOF
    */1 * * * * $SCRIPT_PATH >> /root/$(basename $SCRIPT_PATH).log
    EOF

  EOT
}
