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

  // VPC configuration
  vpc_cidr_block     = module.vpc.vpc_cidr_block
  vpc_id             = module.vpc.vpc_id
  subnet_id          = module.vpc.public_subnets[0]
  security_group_ids = [aws_security_group.tailscale.id]
  instance_type      = "c5.9xlarge"
}

// VPC for the 10G networking example (Region 1)
module "vpc" {
  source = "../internal-modules/aws-vpc"
  name = local.name
  tags = local.aws_tags
  cidr = "10.0.80.0/22"
  public_subnets  = ["10.0.80.0/24"]
  private_subnets = ["10.0.81.0/24"]
}

// VPC for the 10G networking example (Region 2)
module "vpc_2" {
  source = "../internal-modules/aws-vpc"
  providers = { aws = aws.region2 }
  name = "${local.name}-region2"
  tags = local.aws_tags
  cidr = "10.0.88.0/22"
  public_subnets  = ["10.0.88.0/24"]
  private_subnets = ["10.0.89.0/24"]
}

resource "tailscale_tailnet_key" "main" {
  ephemeral           = true
  preauthorized       = true
  reusable            = true
  recreate_if_invalid = "always"
  tags                = local.tailscale_acl_tags
}

// First EC2 instance (Region 1)
module "tailscale_aws_ec2_instance_1" {
  source = "../internal-modules/aws-ec2-instance"
  instance_type         = local.instance_type
  instance_architecture = "x86_64"
  instance_key_name     = var.aws_key_pair_name
  instance_tags = merge(local.aws_tags, { Name = "${local.name}-instance-1" })
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.tailscale.id]
  tailscale_hostname        = "${local.name}-instance-1"
  tailscale_auth_key        = tailscale_tailnet_key.main.key
  tailscale_set_preferences = local.tailscale_set_preferences
  depends_on = [ module.vpc.nat_ids, ]
}

// Second EC2 instance (Region 2)
module "tailscale_aws_ec2_instance_2" {
  source = "../internal-modules/aws-ec2-instance"
  providers = { aws = aws.region2 }
  instance_type         = local.instance_type
  instance_architecture = "x86_64"
  instance_key_name     = var.aws_key_pair_name
  instance_tags = merge(local.aws_tags, { Name = "${local.name}-instance-2" })
  subnet_id              = module.vpc_2.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.tailscale_2.id]
  tailscale_hostname        = "${local.name}-instance-2"
  tailscale_auth_key        = tailscale_tailnet_key.main.key
  tailscale_set_preferences = local.tailscale_set_preferences
  depends_on = [ module.vpc_2.nat_ids, ]
}

// Elastic IPs for both instances to ensure public IP addresses
resource "aws_eip" "instance_1" {
  instance = module.tailscale_aws_ec2_instance_1.instance_id
  tags = merge(local.aws_tags, { Name = "${local.name}-instance-1-eip" })
}

resource "aws_eip" "instance_2" {
  provider = aws.region2
  instance = module.tailscale_aws_ec2_instance_2.instance_id
  tags = merge(local.aws_tags, { Name = "${local.name}-instance-2-eip" })
}

// Security group for region 1
resource "aws_security_group" "tailscale" {
  vpc_id = module.vpc.vpc_id
  name   = local.name
}

// Security group for region 2
resource "aws_security_group" "tailscale_2" {
  provider = aws.region2
  vpc_id   = module.vpc_2.vpc_id
  name     = "${local.name}-region2"
}

// Security group rules for region 1
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
  cidr_blocks       = [module.vpc.vpc_cidr_block]
}
resource "aws_security_group_rule" "ssh_ingress" {
  security_group_id = aws_security_group.tailscale.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "high_bandwidth_ingress" {
  security_group_id        = aws_security_group.tailscale.id
  type                     = "ingress"
  from_port                = 1024
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.tailscale.id
}

// Security group rules for region 2
resource "aws_security_group_rule" "tailscale_ingress_2" {
  provider          = aws.region2
  security_group_id = aws_security_group.tailscale_2.id
  type              = "ingress"
  from_port         = 41641
  to_port           = 41641
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}
resource "aws_security_group_rule" "egress_2" {
  provider          = aws.region2
  security_group_id = aws_security_group.tailscale_2.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}
resource "aws_security_group_rule" "internal_vpc_ingress_ipv4_2" {
  provider          = aws.region2
  security_group_id = aws_security_group.tailscale_2.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [module.vpc_2.vpc_cidr_block]
}
resource "aws_security_group_rule" "ssh_ingress_2" {
  provider          = aws.region2
  security_group_id = aws_security_group.tailscale_2.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "high_bandwidth_ingress_2" {
  provider                  = aws.region2
  security_group_id         = aws_security_group.tailscale_2.id
  type                      = "ingress"
  from_port                 = 1024
  to_port                   = 65535
  protocol                  = "tcp"
  source_security_group_id  = aws_security_group.tailscale_2.id
} 