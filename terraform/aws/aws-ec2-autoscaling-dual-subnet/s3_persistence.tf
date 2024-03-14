locals {
  routes_file_s3_basepath        = "s3://${aws_s3_bucket.routes.bucket}"
  app_name                       = "aws"
  routes_file_s3_instance_prefix = "tailscale-appconnector-routes/app-${local.app_name}"

  script_routes_restore = <<-EOT
    #!/bin/bash

    set -e

    apt-get -qq update
    apt-get -yqq install jq
    apt-get -yqq install awscli

    SCRIPT_PATH=/root/tailscale-appconnector-routes-restore.sh
    ROUTES_TO_RESTORE_DIR=/root/tailscale-appconnector-${local.app_name}-routes-to-restore/
    mkdir -p $ROUTES_TO_RESTORE_DIR

    # save to a file so we can re-run in the future if neeeded
    cat << EOF > $SCRIPT_PATH
    #!/bin/bash

    set -e

    ROUTES_TO_RESTORE_DIR=$ROUTES_TO_RESTORE_DIR

    AWS_TOKEN=\`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"\`
    AWS_ZONE_ID=\`curl -s -H "X-aws-ec2-metadata-token: \$AWS_TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone-id\`
    AWS_REGION=\`echo \$AWS_ZONE_ID | cut -d'-' -f1\`

    S3_OBJECT_FULLPATH=${local.routes_file_s3_basepath}/${local.routes_file_s3_instance_prefix}/\$AWS_REGION/

    # skip the first two lines which are the device's own tailscale addresses
    tailscale status --json | jq -r .Self.AllowedIPs[] | tail -n +3 > \$ROUTES_TO_RESTORE_DIR/initial-routes-from-userdata.txt

    aws s3 cp \
      --recursive \
      \$S3_OBJECT_FULLPATH \
      \$ROUTES_TO_RESTORE_DIR

    ROUTES=\$(cat \$ROUTES_TO_RESTORE_DIR/* | sort -u | tr '\n' ',' | sed 's/[,]$//') # TODO: strip empty lines
    ROUTES_COUNT=\$(cat \$ROUTES_TO_RESTORE_DIR/* | sort -u | wc -l)
    echo \`date -u +"%Y-%m-%dT%H:%M:%SZ"\`": restoring [\$ROUTES_COUNT] routes from \$S3_OBJECT_FULLPATH"
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
    ROUTES_TO_PERSIST_DIR=/root/tailscale-appconnector-${local.app_name}-routes-to-persist/
    mkdir -p $ROUTES_TO_PERSIST_DIR

    # save to a file so we can re-run in the future if neeeded, and schedule via cron
    cat << EOF > $SCRIPT_PATH
    #!/bin/bash

    CURRENT_TIME=\`date -u +"%Y-%m-%dT%H:%M:%SZ"\`
    ROUTES_TO_PERSIST_DIR=$ROUTES_TO_PERSIST_DIR\$CURRENT_TIME/
    mkdir -p \$ROUTES_TO_PERSIST_DIR

    AWS_TOKEN=\`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"\`
    AWS_ZONE_ID=\`curl -s -H "X-aws-ec2-metadata-token: \$AWS_TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone-id\`
    AWS_REGION=\`echo \$AWS_ZONE_ID | cut -d'-' -f1\`
    AWS_AMI_LAUNCH_INDEX=\`curl -s -H "X-aws-ec2-metadata-token: \$AWS_TOKEN" http://169.254.169.254/latest/meta-data/ami-launch-index\`
    
    LOCAL_FILE_FULLPATH=\$ROUTES_TO_PERSIST_DIR/routes.tmp
    S3_OBJECT_FULLPATH=${local.routes_file_s3_basepath}/${local.routes_file_s3_instance_prefix}/\$AWS_REGION/\$AWS_ZONE_ID-ami-launch-index-\$AWS_AMI_LAUNCH_INDEX.txt

    tailscale status --json | jq -r .Self.AllowedIPs[] | tail -n +3 > \$LOCAL_FILE_FULLPATH
    ROUTES_COUNT=\$(cat \$LOCAL_FILE_FULLPATH | wc -l)

    echo \$CURRENT_TIME": saving [\$ROUTES_COUNT] routes to \$S3_OBJECT_FULLPATH"

    # skip the first two lines which are the device's own tailscale addresses
    aws s3 cp \
      \$LOCAL_FILE_FULLPATH \
      \$S3_OBJECT_FULLPATH

    EOF

    chmod +x $SCRIPT_PATH

    crontab << EOF
    */1 * * * * $SCRIPT_PATH >> /root/$(basename $SCRIPT_PATH).log
    EOF

  EOT
}
