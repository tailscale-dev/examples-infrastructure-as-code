locals {
  name = "dpi-${basename(path.cwd)}"

  aws_tags = {
    Name = local.name
  }

  tailscale_acl_tags = [
    "tag:example-infra",
    "tag:example-exitnode",
    # "tag:example-subnetrouter",
    # "tag:example-appconnector",
  ]
  #   tailscale_set_preferences = [
  #     "--auto-update",
  #     "--ssh",
  #     "--advertise-exit-node",
  #     # "--advertise-connector",
  #     # "--advertise-routes=${join(",", [
  #     #   local.vpc_cidr_block,
  #     # ])}",
  #   ]

  // Modify these to use your own VPC
  vpc_cidr_block     = module.vpc.vpc_cidr_block
  vpc_id             = module.vpc.vpc_id
  subnet_id          = module.vpc.public_subnets[0]
  security_group_ids = [aws_security_group.tailscale.id]
  instance_type      = "c7g.medium"
}

resource "aws_key_pair" "cameron" {
  key_name   = "cameron"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINAEJIpfr+S0Ko8xWS5dUGELoLW9A+a4PCVR4KHEx9ad cameron@tailscale.com"
}

// Remove this to use your own VPC.
module "vpc" {
  source = "../internal-modules/aws-vpc"

  name = local.name
  tags = local.aws_tags

  cidr = "10.0.80.0/22"

  public_subnets  = ["10.0.80.0/24"]
  private_subnets = ["10.0.81.0/24"]
}

resource "tailscale_tailnet_key" "main" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags                = local.tailscale_acl_tags
}

resource "aws_security_group" "tailscale" {
  vpc_id = local.vpc_id
  name   = local.name
}

resource "aws_security_group_rule" "all_internal_udp" {
  security_group_id = aws_security_group.tailscale.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "udp"
  cidr_blocks = [
    module.vpc.vpc_cidr_block,
    "0.0.0.0/0",
  ]
  ipv6_cidr_blocks = ["::/0"]
}

resource "aws_security_group_rule" "all_internal_tcp" {
  security_group_id = aws_security_group.tailscale.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "tcp"
  cidr_blocks = [
    module.vpc.vpc_cidr_block,
    "0.0.0.0/0",
  ]
  ipv6_cidr_blocks = ["::/0"]
}

resource "aws_security_group_rule" "ssh" {
  security_group_id = aws_security_group.tailscale.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "tailscale_ingress" {
  security_group_id = aws_security_group.tailscale.id
  type              = "ingress"
  from_port         = 41641
  to_port           = 41641
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}

resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.tailscale.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}

resource "aws_security_group_rule" "internal_vpc_ingress_ipv4" {
  security_group_id = aws_security_group.tailscale.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [local.vpc_cidr_block]
}

module "exitnode" {
  source = "../internal-modules/aws-ec2-instance"

  instance_type = local.instance_type
  instance_tags = merge(local.aws_tags, {
    Name = "${local.name}-exitnode"
  })

  subnet_id              = local.subnet_id
  vpc_security_group_ids = local.security_group_ids

  # Variables for Tailscale resources
  tailscale_hostname = "${local.name}-exitnode"
  tailscale_auth_key = tailscale_tailnet_key.main.key
  tailscale_set_preferences = [
    "--auto-update",
    "--ssh",
    "--advertise-exit-node",
    # "--advertise-connector",
    # "--advertise-routes=${join(",", [
    #   local.vpc_cidr_block,
    # ])}",
  ]

    additional_after_scripts = [
    <<-EOT
    #!/bin/bash

    echo -e '\n#\n# Beginning DPI forwarding configuration...\n#\n'

    export TS_INTERFACE=tailscale0
    export DPI_ADDRESS=${module.dpi.instance_private_ip}
    export DPI_PORT=8080

    sudo iptables -t nat -A PREROUTING -i $TS_INTERFACE -p tcp --dport 80  -j DNAT --to-destination $DPI_ADDRESS:$DPI_PORT
    sudo iptables -t nat -A PREROUTING -i $TS_INTERFACE -p tcp --dport 443 -j DNAT --to-destination $DPI_ADDRESS:$DPI_PORT
    sudo iptables -t nat -A POSTROUTING -o $TS_INTERFACE -j MASQUERADE

    echo -e '\n#\n# DPI forwarding configuration complete.\n#\n'
    EOT
  ]

  depends_on = [
    module.vpc.nat_ids, # remove if using your own VPC otherwise ensure provisioned NAT gateway is available
  ]
}

output "exitnode-addresses" {
  value = [module.exitnode.instance_public_ip, module.exitnode.instance_private_ip]
}

module "dpi" {
  source = "../internal-modules/aws-ec2-instance"

  instance_type = local.instance_type
  instance_tags = merge(local.aws_tags, {
    Name = "${local.name}-dpi"
  })

  instance_key_name = aws_key_pair.cameron.key_name

  subnet_id              = local.subnet_id
  vpc_security_group_ids = local.security_group_ids

  # Variables for Tailscale resources
  tailscale_hostname = "${local.name}-dpi"
  tailscale_auth_key = tailscale_tailnet_key.main.key
  tailscale_set_preferences = [
    "--auto-update",
    "--ssh",
    # "--advertise-exit-node",
    # "--advertise-connector",
    # "--advertise-routes=${join(",", [
    #   local.vpc_cidr_block,
    # ])}",
  ]

  additional_after_scripts = [
    <<-EOT
    #!/bin/bash

    echo -e '\n#\n# Beginning mitmproxy installation...\n#\n'

    apt-get -yqq update
    apt-get -yqq install mitmproxy

    cat << INNEREOT > /etc/systemd/system/mitmweb.service
[Unit]
Description=mitmweb
After=network.target

[Service]
ExecStart=/usr/bin/mitmweb --web-host 0.0.0.0
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target

INNEREOT

    systemctl daemon-reload
    systemctl enable mitmweb
    systemctl start mitmweb

    echo -e '\n#\n# mitmproxy/mitmweb complete.\n#\n'
    EOT
  ]

  depends_on = [
    module.vpc.nat_ids, # remove if using your own VPC otherwise ensure provisioned NAT gateway is available
  ]
}

output "dpi-addresses" {
  value = [module.dpi.instance_public_ip, module.dpi.instance_private_ip]
}
