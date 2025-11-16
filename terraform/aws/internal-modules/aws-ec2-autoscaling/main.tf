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

resource "aws_launch_template" "tailscale" {
  name_prefix   = var.autoscaling_group_name
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.instance_key_name

  network_interfaces {
    # associate_public_ip_address = true # TODO(clstokes): remove
    subnet_id       = var.subnet_id
    security_groups = var.security_group_ids
  }

  dynamic "iam_instance_profile" {
    for_each = var.instance_profile_name != "" ? [1] : []
    content {
      name = var.instance_profile_name
    }
  }

  metadata_options {
    http_endpoint = var.instance_metadata_options["http_endpoint"]
    http_tokens   = var.instance_metadata_options["http_tokens"]
  }

  # TODO(clstokes): remove
  #   dynamic "network_interfaces" {
  #     # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/scenarios-enis.html#creating-dual-homed-instances-with-workloads-roles-on-distinct-subnets
  #     for_each = var.network_interfaces
  #     content {
  #       delete_on_termination = false
  #       device_index          = network_interfaces.key
  #       network_interface_id  = network_interfaces.value
  #     }
  #   }

  tag_specifications {
    resource_type = "instance"
    tags          = var.instance_tags
  }

  user_data = module.tailscale_install_scripts.ubuntu_install_script_base64_encoded

  lifecycle {
    ignore_changes = [
      image_id,
    ]
  }
}

resource "aws_autoscaling_group" "tailscale" {
  name = var.autoscaling_group_name

  launch_template {
    id      = aws_launch_template.tailscale.id
    version = aws_launch_template.tailscale.latest_version
  }

  desired_capacity = 1
  min_size         = 0
  max_size         = 1

  /**
   * Uncomment to allow ASG to replace the instance. It will take several minutes as the ASG 
   * will try to launch a replacement instance before ENIs have been released.

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
    }
  }
  */

  health_check_grace_period = 300
  health_check_type         = "EC2"

  timeouts {
    delete = "15m"
  }
}
