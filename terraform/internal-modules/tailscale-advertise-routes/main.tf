locals {
  routes_to_advertise = length(var.tailscale_advertise_routes) == 0

  advertise_routes_script = local.routes_to_advertise ? "" : templatefile(
    "${path.module}/scripts/advertise-routes.bash.tftpl",
    {
      tailscale_advertise_routes                   = join(",", var.tailscale_advertise_routes),
      tailscale_advertise_routes_from_file_on_host = var.tailscale_advertise_routes_from_file_on_host
    }
  )
}
