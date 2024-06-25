resource "tailscale_tailnet_key" "main" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags = [
    "tag:example-infra",
    "tag:example-subnetrouter",
  ]
}

resource "aws_security_group" "prod" {
  vpc_id = module.prod_vpc.vpc_id

  tags = merge(local.tags, { Name = "${local.name}-prod" })
}

resource "aws_security_group_rule" "prod_vpc_egress" {
  security_group_id = aws_security_group.prod.id

  type      = "egress"
  from_port = 0
  to_port   = 0
  protocol  = "-1"
  cidr_blocks = [
    "0.0.0.0/0",
  ]
}

resource "aws_security_group_rule" "prod_vpc_ingress" {
  security_group_id = aws_security_group.prod.id

  type      = "ingress"
  from_port = 0
  to_port   = 0
  protocol  = "-1"
  cidr_blocks = [
    # module.prod_vpc.vpc_cidr_block,
    # module.mgmt_vpc.vpc_cidr_block,
    "10.0.0.0/8",
    "192.168.0.0/20",
  ]
}

resource "aws_network_interface" "primary" {
  subnet_id = module.prod_vpc.public_subnets[0]
  security_groups = [
    # module.prod_vpc.tailscale_security_group_id,
    aws_security_group.prod.id,
  ]
  tags = merge(local.tags, { Name = "${local.name}-prod-primary" })
}
resource "aws_eip" "primary" {
  tags = local.tags
}
resource "aws_eip_association" "primary" {
  network_interface_id = aws_network_interface.primary.id
  allocation_id        = aws_eip.primary.id
}

resource "aws_network_interface" "secondary" {
  subnet_id = module.prod_vpc.private_subnets[0]
  security_groups = [
    # module.prod_vpc.tailscale_security_group_id,
    aws_security_group.prod.id,
  ]
  tags = merge(local.tags, { Name = "${local.name}-prod-secondary" })

  source_dest_check = false
}

module "tailscale_aws_ec2_autoscaling" {
  source = "../internal-modules/aws-ec2-autoscaling/"

  autoscaling_group_name = local.name
  instance_type          = var.instance_type
  instance_tags          = merge(local.tags, { Name = "${local.name}-prod" })

  network_interfaces = [
    aws_network_interface.primary.id, # first NIC must be in PUBLIC subnet
    aws_network_interface.secondary.id,
  ]

  # Variables for Tailscale resources
  tailscale_hostname        = "${local.name}-prod"
  tailscale_auth_key        = tailscale_tailnet_key.main.key
  tailscale_set_preferences = var.tailscale_set_preferences
  tailscale_ssh             = true
  # tailscale_advertise_exit_node = true

  tailscale_advertise_routes = [
    module.mgmt_vpc.vpc_cidr_block,
    module.staging_vpc.vpc_cidr_block,
  ]

  # tailscale_advertise_connector = true
  # tailscale_advertise_aws_service_names = [
  #   "GLOBALACCELERATOR",
  # ]

  additional_after_scripts = [
    local.netplan_tgw
  ]

  depends_on = [
    module.prod_vpc.natgw_ids, # ensure NAT gateway is available before instance provisioning - primarily for private subnets
  ]
}

locals {
  netplan_tgw_subnet_public  = module.prod_vpc.public_subnets_cidr_blocks[0]
  netplan_tgw_subnet_private = module.prod_vpc.private_subnets_cidr_blocks[0]

  netplan_tgw = <<-EOF
  #!/bin/bash
  #
  # Configures routing via netplan to allow routing between two networks.
  # https://people.ubuntu.com/~slyon/netplan-docs/examples/#configuring-source-routing
  #

  echo -e '\n#\n# Beginning dual-subnet netplan configuration...\n#\n'

  TAILSCALE_NETPLAN_FILE=/etc/netplan/52-tailscale-custom-routes.yaml

  PRIMARY_NETDEV=$(ip route show ${local.netplan_tgw_subnet_public} | cut -d' ' -f3)
  SECONDARY_NETDEV=$(ip route show ${local.netplan_tgw_subnet_private} | cut -d' ' -f3)

  PRIMARY_NETDEV_IP=$(ip route show ${local.netplan_tgw_subnet_public} | cut -d' ' -f9)
  SECONDARY_NETDEV_IP=$(ip route show ${local.netplan_tgw_subnet_private} | cut -d' ' -f9)

  cat <<EOT > $TAILSCALE_NETPLAN_FILE
  network:
      ethernets:
          $PRIMARY_NETDEV: # public interface
              dhcp4: true
              dhcp6: false
              match:
                  macaddress: $(cat /sys/class/net/$PRIMARY_NETDEV/address)
              set-name: $PRIMARY_NETDEV
              # routes:
              # - table: 101
              #   to: ${local.netplan_tgw_subnet_public}
              #   via: ${cidrhost(local.netplan_tgw_subnet_public, 1)}
              # routing-policy:
              # - table: 101
              #   from: ${local.netplan_tgw_subnet_public}
          $SECONDARY_NETDEV: # private interface
              dhcp4: true
              dhcp4-overrides:
                  route-metric: 100
              dhcp6: false
              match:
                  macaddress: $(cat /sys/class/net/$SECONDARY_NETDEV/address)
              set-name: $SECONDARY_NETDEV
              routes:
              - table: 102
                to: ${module.mgmt_vpc.vpc_cidr_block}
                via: ${cidrhost(module.mgmt_vpc.vpc_cidr_block, 1)}
              routes:
              - table: 102
                to: ${module.staging_vpc.vpc_cidr_block}
                via: ${cidrhost(module.staging_vpc.vpc_cidr_block, 1)}
              routing-policy:
              - table: 102
                from: $SECONDARY_NETDEV_IP
      version: 2
  EOT

  chmod 600 $TAILSCALE_NETPLAN_FILE

  mv /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml.old

  # netplan apply

  systemctl list-unit-files tailscaled.service > /dev/null
  if [ $? -eq 0 ]; then
      systemctl restart tailscaled
      echo -e '\n#\n# Tailscale restart complete.\n#\n'
  fi

  #
  # pause briefly to let route changes "settle"
  # without this, immediate network connections (e.g. curl google.com) fail with 'unknown host'
  #
  sleep 1

  echo -e '\n#\n# Complete.\n#\n'
  EOF
}

# output "netplan_tgw" {
#   value = local.netplan_tgw
# }
