locals {
  name = "example-${basename(path.cwd)}"

  aws_tags = {
    Name = local.name
  }

  tailscale_acl_tags = [
    "tag:example-infra",
    "tag:example-nat44connector-alpha",
  ]
  tailscale_set_preferences = [
    "--auto-update",
    "--ssh",
    "--accept-dns=false", # required to not create infinite loop of DNS lookups - NAT44->NAT44(self)->NAT44(self)
  ]

  // Modify these to use your own VPC
  vpc_cidr_block     = module.vpc.vpc_cidr_block
  vpc_id             = module.vpc.vpc_id
  subnet_id          = module.vpc.public_subnets[0]
  private_subnet_id  = module.vpc.private_subnets[0]
  security_group_ids = [aws_security_group.tailscale.id]
  instance_type      = "t4g.micro"

  nat44_v4_pfx = "100.64.0.0/16"
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

resource "aws_network_interface" "primary" {
  subnet_id       = local.subnet_id
  security_groups = local.security_group_ids
  tags            = merge(local.aws_tags, { Name = "${local.name}-primary" })
}
resource "aws_eip" "primary" {
  tags = local.aws_tags
}
resource "aws_eip_association" "primary" {
  network_interface_id = aws_network_interface.primary.id
  allocation_id        = aws_eip.primary.id
}

resource "aws_network_interface" "secondary" {
  subnet_id       = local.private_subnet_id
  security_groups = local.security_group_ids
  tags            = merge(local.aws_tags, { Name = "${local.name}-secondary" })

  source_dest_check = false
}

module "tailscale_aws_ec2_autoscaling" {
  source = "../internal-modules/aws-ec2-autoscaling/"

  autoscaling_group_name = local.name
  instance_type          = local.instance_type
  instance_tags          = local.aws_tags

  network_interfaces = [
    aws_network_interface.primary.id, # first NIC must be in PUBLIC subnet
    aws_network_interface.secondary.id,
  ]

  # Variables for Tailscale resources
  tailscale_hostname        = local.name
  tailscale_auth_key        = tailscale_tailnet_key.main.key
  tailscale_set_preferences = local.tailscale_set_preferences

  additional_after_scripts = [
    <<-EOT

    git clone https://github.com/tailscale/tailscale /root/tailscale-nat44
    cd /root/tailscale-nat44
    # git fetch
    # git checkout 8b962f23d194ae0999c296a5a3250d0e77dadf57
    
    cat << INNEREOT2 > /etc/systemd/system/tailscale-nat44.service
[Unit]
Description=tailscale-nat44
After=network.target

[Service]
WorkingDirectory=/root/tailscale-nat44
Environment=TAILSCALE_USE_WIP_CODE=1
Environment=TS_AUTH_KEY=${tailscale_tailnet_key.nat44.key}
ExecStart=/root/tailscale-nat44/tool/go run ./cmd/natc --hostname=${local.name}-tsnet --site-id=10 --v4-pfx=${local.nat44_v4_pfx}
Restart=on-failure
User=root
LimitNOFILE=10240

[Install]
WantedBy=multi-user.target

INNEREOT2

    systemctl daemon-reload
    systemctl enable tailscale-nat44
    systemctl start tailscale-nat44

    EOT
  ]

  depends_on = [
    module.vpc.natgw_ids, # ensure NAT gateway is available before instance provisioning - primarily for private subnets
  ]
}

resource "tailscale_tailnet_key" "nat44" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags                = ["tag:example-nat44connector-alpha"]
}

locals {
  nat44_domains = [
    "whatismyipaddress.com",
  ]
}

resource "tailscale_dns_split_nameservers" "nat44" {
  count = length(local.nat44_domains)

  domain      = local.nat44_domains[count.index]
  nameservers = [cidrhost(local.nat44_v4_pfx,0)]

  depends_on = [
    module.tailscale_aws_ec2_autoscaling, # wait for ASG before setting split dns
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
