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
  tags                = ["tag:example-infra"]
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

module "tailscale_aws_ec2_autoscaling" {
  source = "../internal-modules/aws-ec2-autoscaling/"

  autoscaling_group_name = local.name
  instance_type          = "t4g.2xlarge"
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

  tailscale_set_preferences = [
    "--accept-dns=false",
  ]

  additional_after_scripts = [
    <<-EOT

    git clone https://github.com/tailscale/tailscale /root/appc
    cd /root/appc
    git fetch
    git checkout e2f8436adb71fe41e9c4d063a26748967d571c5a
    
    cat << INNEREOT2 > /etc/systemd/system/appc.service
[Unit]
Description=appc
After=network.target

[Service]
WorkingDirectory=/root/appc
Environment=TS_AUTH_KEY=${tailscale_tailnet_key.appc.key}
ExecStart=/root/appc/tool/go run ./cmd/appc --hostname=${local.name}-appc --site-id=10 --v4-pfx=100.64.10.8/30
Restart=on-failure
User=root
LimitNOFILE=10240

[Install]
WantedBy=multi-user.target

INNEREOT2

    systemctl daemon-reload
    systemctl enable appc
    systemctl start appc

    EOT
  ]

  depends_on = [
    module.vpc.natgw_ids, # ensure NAT gateway is available before instance provisioning - primarily for private subnets
  ]
}

resource "tailscale_tailnet_key" "appc" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags                = ["tag:example-appconnector-alpha"]
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

# resource "tailscale_dns_split_nameservers" "aws" {
#   count = length(local.aws_domains)

#   domain      = local.aws_domains[count.index]
#   nameservers = ["100.64.1.0"]

#   depends_on = [
#     module.tailscale_aws_ec2_autoscaling, # wait for ASG before setting split dns
#   ]
# }
