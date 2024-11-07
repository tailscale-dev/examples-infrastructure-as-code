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
  ]

  ip_forwarding_required = length([for x in var.tailscale_set_preferences : x if strcontains(x, "advertise")]) > 0
  ip_forwarding_script   = local.ip_forwarding_required == false ? "" : templatefile("${path.module}/scripts/additional-scripts/ip-forwarding.tftpl", {})

  ethtool_udp_optimization_script = templatefile("${path.module}/scripts/additional-scripts/ethtool-udp.tftpl", {})
}
