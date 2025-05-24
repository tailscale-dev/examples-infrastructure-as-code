module "tailscale_install_scripts" {
  source = "../../../internal-modules/tailscale-install-scripts"

  tailscale_auth_key        = var.tailscale_auth_key
  tailscale_hostname        = var.tailscale_hostname
  tailscale_set_preferences = var.tailscale_set_preferences

  additional_before_scripts = var.additional_before_scripts
  additional_after_scripts  = var.additional_after_scripts

  primary_subnet_cidr   = data.aws_subnet.primary.cidr_block
  secondary_subnet_cidr = data.aws_subnet.secondary.cidr_block
}

data "aws_network_interface" "selected" {
  count = length(var.network_interfaces)
  id    = var.network_interfaces[count.index]
}

# Only get the unique subnets (primary and secondary)
data "aws_subnet" "primary" {
  id = data.aws_network_interface.selected[0].subnet_id  # First ENI is always primary (public)
}

data "aws_subnet" "secondary" {
  id = data.aws_network_interface.selected[1].subnet_id  # Second ENI is always secondary (private)
}

# Calculate the maximum number of instances based on network interfaces
# Assumes pairs of interfaces (public + private per instance)
locals {
  interfaces_per_instance = var.interfaces_per_instance
  max_instances = length(var.network_interfaces) / local.interfaces_per_instance
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

# Create separate launch templates for each instance index
# This allows each instance to get its specific ENI pair
resource "aws_launch_template" "tailscale" {
  count = local.max_instances
  
  name_prefix   = "${var.autoscaling_group_name}-${count.index + 1}"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.instance_key_name

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

  # Assign specific ENI pair to this launch template
  dynamic "network_interfaces" {
    for_each = range(local.interfaces_per_instance)
    content {
      delete_on_termination = false
      device_index          = network_interfaces.value
      network_interface_id  = var.network_interfaces[count.index * local.interfaces_per_instance + network_interfaces.value]
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.instance_tags, {
      Name = "${var.autoscaling_group_name}-${count.index + 1}"
    })
  }

  user_data = module.tailscale_install_scripts.ubuntu_install_script_base64_encoded

  lifecycle {
    ignore_changes = [
      image_id,
    ]
  }
}

# Create individual ASGs for each instance to ensure proper ENI assignment
resource "aws_autoscaling_group" "tailscale" {
  count = local.max_instances
  
  name = "${var.autoscaling_group_name}-${count.index + 1}"

  launch_template {
    id      = aws_launch_template.tailscale[count.index].id
    version = aws_launch_template.tailscale[count.index].latest_version
  }

  # Use the primary subnet's AZ since all ENIs for an instance must be in the same AZ
  availability_zones = [data.aws_subnet.primary.availability_zone]

  desired_capacity = count.index < var.desired_capacity ? 1 : 0
  min_size         = 0
  max_size         = 1  # Each ASG manages exactly one instance

  health_check_grace_period = 300
  health_check_type         = "EC2"

  timeouts {
    delete = "15m"
  }

  tag {
    key                 = "Name"
    value               = "${var.autoscaling_group_name}-${count.index + 1}"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.instance_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
