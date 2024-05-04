locals {
  name = var.name != "" ? var.name : "example-${basename(path.cwd)}"

  tags = length(var.tags) > 0 ? var.tags : {
    Name = local.name
  }
}

module "vpc" {
  source = "../internal-modules/aws-vpc"

  name = local.name
  tags = local.tags

  cidr = var.vpc_cidr_block

  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
}

resource "tailscale_tailnet_key" "main" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags                = var.tailscale_device_tags
}

resource "aws_network_interface" "primary" {
  subnet_id       = module.vpc.public_subnets[0]
  security_groups = [module.vpc.tailscale_security_group_id]
  tags            = merge(local.tags, { Name = "${local.name}-primary" })
}
resource "aws_eip" "primary" {
  tags = local.tags
}
resource "aws_eip_association" "primary" {
  network_interface_id = aws_network_interface.primary.id
  allocation_id        = aws_eip.primary.id
}

resource "aws_network_interface" "secondary" {
  subnet_id       = module.vpc.private_subnets[0]
  security_groups = [module.vpc.tailscale_security_group_id]
  tags            = merge(local.tags, { Name = "${local.name}-secondary" })

  source_dest_check = false
}

variable "coredns_ipv6_address" {
  default = "fd12:3456:789a:1:1:2:3:4" # TODO: move to terraform.tfvars?
}

data "tailscale_4via6" "internet" {
  site = 123 # TODO: move to terraform.tfvars
  cidr = "0.0.0.0/0"
}

module "tailscale_aws_ec2_autoscaling" {
  source = "../internal-modules/aws-ec2-autoscaling/"

  autoscaling_group_name = local.name
  instance_type          = var.instance_type
  instance_tags          = local.tags

  network_interfaces = [
    aws_network_interface.primary.id, # first NIC must be in PUBLIC subnet
    aws_network_interface.secondary.id,
  ]

  # Variables for Tailscale resources
  tailscale_hostname            = local.name
  tailscale_auth_key            = tailscale_tailnet_key.main.key
  tailscale_ssh                 = true
  tailscale_advertise_exit_node = false

  tailscale_advertise_routes = [
    "${var.coredns_ipv6_address}/128",
    data.tailscale_4via6.internet.ipv6,
  ]

  tailscale_set_preferences = [
    "--accept-dns=false", // required for userdata script to run successfully if tailnet is already configured for split dns and another coredns is not available
  ]
  additional_after_scripts = [
    <<-EOT
    ip addr add ${var.coredns_ipv6_address} dev lo

    wget https://github.com/coredns/coredns/releases/download/v1.11.1/coredns_1.11.1_linux_arm64.tgz
    tar xvzf coredns_1.11.1_linux_arm64.tgz
    mv coredns /usr/local/sbin/

    mkdir -p /root/coredns-config
    cat << INNEREOT1 > /root/coredns-config/Corefile
.:53 {
    bind tailscale0
    bind ${var.coredns_ipv6_address}

    forward . [${var.coredns_ipv6_address}]:54
    log

    template ANY A {
         rcode NOERROR
    }
}

.:54 {
    bind tailscale0
    bind ${var.coredns_ipv6_address}
    reload 2s 1s

    log

    forward . tls://1.1.1.1 tls://1.0.0.1 {
       tls_servername cloudflare-dns.com
       health_check 5s
    }

    dns64 {
        prefix ${data.tailscale_4via6.internet.ipv6}
        translate_all
        allow_ipv4
    }

}
INNEREOT1

    cd /root/coredns-config
    
    cat << INNEREOT2 > /etc/systemd/system/coredns.service
[Unit]
Description=CoreDNS DNS server
After=network.target

[Service]
ExecStart=/usr/local/sbin/coredns -conf /root/coredns-config/Corefile
Restart=on-failure
User=root
LimitNOFILE=10240

[Install]
WantedBy=multi-user.target

INNEREOT2

    systemctl daemon-reload
    systemctl enable coredns
    systemctl start coredns

    EOT
  ]

  depends_on = [
    module.vpc.natgw_ids, # ensure NAT gateway is available before instance provisioning - primarily for private subnets
  ]
}

locals {
  aws_domains = [
    "amazonaws.com",
    "aws.amazon.com",
    "cname-proxy.amazon.com",
    "awsglobalaccelerator.com",
    "whatismyipaddress.com", # TODO: remove
  ]
}

resource "tailscale_dns_split_nameservers" "aws" {
  count = length(local.aws_domains)

  domain      = local.aws_domains[count.index]
  nameservers = [var.coredns_ipv6_address]

  depends_on = [
    module.tailscale_aws_ec2_autoscaling, # wait for ASG before setting split dns
  ]
}
