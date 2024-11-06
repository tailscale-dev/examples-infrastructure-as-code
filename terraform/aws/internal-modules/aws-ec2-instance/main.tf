module "tailscale_install_scripts" {
  source = "../../../internal-modules/tailscale-install-scripts"

  tailscale_auth_key        = var.tailscale_auth_key
  tailscale_hostname        = var.tailscale_hostname
  tailscale_set_preferences = var.tailscale_set_preferences

  additional_before_scripts = var.additional_before_scripts
  additional_after_scripts  = var.additional_after_scripts
}

data "aws_ami" "ubuntu" {
  owners      = ["099720109477"] # Canonical
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-*-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

resource "aws_instance" "tailscale_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.instance_key_name

  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.vpc_security_group_ids
  ipv6_address_count     = var.ipv6_address_count

  iam_instance_profile = var.instance_profile_name

  metadata_options {
    http_endpoint = var.instance_metadata_options["http_endpoint"]
    http_tokens   = var.instance_metadata_options["http_tokens"]
  }

  tags = var.instance_tags

  user_data_replace_on_change = var.instance_user_data_replace_on_change
  user_data                   = module.tailscale_install_scripts.ubuntu_install_script

  lifecycle {
    ignore_changes = [
      ami,
    ]
  }
}
