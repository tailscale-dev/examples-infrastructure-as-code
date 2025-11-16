locals {
  name = "example-${basename(path.cwd)}"

  aws_tags = {
    Name = local.name
  }

  tailscale_acl_tags = [
    "tag:example-infra",
    "tag:example-exitnode",
    "tag:example-subnetrouter",
    "tag:example-appconnector",
  ]
  tailscale_set_preferences = [
    "--auto-update",
    "--ssh",
    "--advertise-connector",
    "--advertise-exit-node",
    "--advertise-routes=${join(",", [
      local.vpc_cidr_block,
    ])}",
  ]

  tailscale_peer_relay_port = 40000

  // Modify these to use your own VPC
  vpc_cidr_block    = module.vpc.vpc_cidr_block
  vpc_id            = module.vpc.vpc_id
  public_subnet_id  = module.vpc.public_subnets[0]
  private_subnet_id = module.vpc.private_subnets[0]
  instance_type     = "c7g.medium"
}

// Remove this to use your own VPC.
module "vpc" {
  source = "../internal-modules/aws-vpc"

  name = local.name
  tags = local.aws_tags
}

resource "tailscale_tailnet_key" "main" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags                = local.tailscale_acl_tags
}

module "connector" {
  source = "../internal-modules/aws-ec2-autoscaling/"

  autoscaling_group_name = local.name
  instance_type          = local.instance_type
  instance_tags          = local.aws_tags

  subnet_id = local.private_subnet_id
  security_group_ids = [
    aws_security_group.tailscale.id,
  ]

  # Variables for Tailscale resources
  tailscale_hostname        = local.name
  tailscale_auth_key        = tailscale_tailnet_key.main.key
  tailscale_set_preferences = local.tailscale_set_preferences

  depends_on = [
    module.vpc.nat_ids, # remove if using your own VPC otherwise ensure provisioned NAT gateway is available
  ]
}

resource "tailscale_tailnet_key" "relay" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags = [
    "tag:example-relay",
  ]
}

module "relay" {
  source = "../internal-modules/aws-ec2-autoscaling/"

  autoscaling_group_name = "${local.name}-relay"
  instance_type          = local.instance_type
  instance_tags = merge(local.aws_tags, {
    Name = "${local.name}-relay"
  })

  subnet_id = local.public_subnet_id
  security_group_ids = [
    aws_security_group.tailscale.id,
    aws_security_group.tailscale_peer_relay.id,
  ]

  # Variables for Tailscale resources
  tailscale_hostname = "${local.name}-relay"
  tailscale_auth_key = tailscale_tailnet_key.relay.key
  tailscale_set_preferences = [
    "--relay-server-port=${local.tailscale_peer_relay_port}",
  ]

  depends_on = [
    module.vpc.nat_ids, # remove if using your own VPC otherwise ensure provisioned NAT gateway is available
  ]
}

resource "aws_security_group" "tailscale" {
  vpc_id = local.vpc_id
  name   = local.name
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

resource "aws_security_group" "tailscale_peer_relay" {
  vpc_id = local.vpc_id
  name   = "${local.name}-relay"
}

resource "aws_security_group_rule" "tailscale_peer_relay_ingress" {
  security_group_id = aws_security_group.tailscale.id
  type              = "ingress"
  from_port         = local.tailscale_peer_relay_port
  to_port           = local.tailscale_peer_relay_port
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}
