locals {
  ubuntu_install_script = templatefile(
    "${path.module}/scripts/tailscale-ubuntu.tftpl",
    {
      tailscale_auth_key        = var.tailscale_auth_key,
      tailscale_arguments       = local.tailscale_arguments,
      tailscale_set_preferences = var.tailscale_set_preferences,

      before_scripts = flatten([ # scripts to run BEFORE tailscale install
        var.additional_before_scripts,
        local.ip_forwarding_script,
        local.netplan_dual_subnet_script,
        local.ethtool_udp_optimization_script, # run after netplan script
      ]),

      after_scripts = flatten([ # scripts to run AFTER tailscale install
        module.tailscale-advertise-routes.routes_script,
        var.additional_after_scripts,
      ]),
    }
  )

  netplan_dual_subnet_script = var.secondary_subnet_cidr == null ? "" : templatefile(
    "${path.module}/scripts/additional-scripts/netplan-dual-subnet.tftpl",
    {
      primary_subnet_cidr   = var.primary_subnet_cidr,
      secondary_subnet_cidr = var.secondary_subnet_cidr,
    }
  )

  tailscale_arguments = [
    "--authkey=${var.tailscale_auth_key}",
    "--hostname=${var.tailscale_hostname}",
    var.tailscale_ssh == false ? "" : "--ssh",
    var.tailscale_advertise_connector == false ? "" : "--advertise-connector",
    var.tailscale_advertise_exit_node == false ? "" : "--advertise-exit-node",
    // Don't set --advertise-routes here, use advertise_routes_script instead.
  ]

  ip_forwarding_required = local.ip_forwarding_script != ""
  ip_forwarding_script = (
    var.tailscale_advertise_exit_node == false
    && var.tailscale_advertise_connector == false
    && length(var.tailscale_advertise_routes) == 0 ?
    "" : templatefile("${path.module}/scripts/additional-scripts/ip-forwarding.tftpl", {})
  )

  ethtool_udp_optimization_script = templatefile("${path.module}/scripts/additional-scripts/ethtool-udp.tftpl", {})
}

module "tailscale-advertise-routes" {
  source                     = "../tailscale-advertise-routes"
  tailscale_advertise_routes = var.tailscale_advertise_routes

  tailscale_advertise_routes_from_file_on_host = "/root/tailscale-routes-to-advertise.txt"
  tailscale_advertise_aws_service_names        = var.tailscale_advertise_aws_service_names
}
