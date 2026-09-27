locals {
  # Names of the SSM Parameter Store SecureString parameters the instance
  # reads at boot. The caller must create parameters with these names.
  tailscale_auth_key_ssm_parameter_name     = "/${var.tailscale_hostname}/tailscale-auth-key"
  windows_admin_password_ssm_parameter_name = "/${var.tailscale_hostname}/windows-admin-password"

  windows_install_script = templatefile(
    "${path.module}/scripts/tailscale-windows.ps1.tftpl",
    {
      auth_key_ssm_parameter_name = local.tailscale_auth_key_ssm_parameter_name,
      tailscale_hostname          = var.tailscale_hostname,
      tailscale_msi_url           = var.tailscale_msi_url,
      username                    = var.windows_admin_username,
      password_ssm_parameter_name = local.windows_admin_password_ssm_parameter_name,
    }
  )
}

data "aws_ami" "windows" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name = "name"
    # values = ["Windows_Server-2022-English-Full-Base-*"]
    values = ["Windows_Server-2025-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "tailscale_instance" {
  ami           = data.aws_ami.windows.id
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
  user_data                   = local.windows_install_script

  lifecycle {
    ignore_changes = [
      ami,
    ]
  }
}
