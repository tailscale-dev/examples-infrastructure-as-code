locals {
  routes_to_advertise = (
    # boolean - do we have any routes to advertise?
    length(var.tailscale_advertise_routes)
    + length(var.tailscale_advertise_aws_service_names)
  ) == 0

  saas_routes_to_advertise = (
    # boolean - do we have any **SaaS** routes to advertise?
    length(var.tailscale_advertise_aws_service_names)
  ) == 0

  advertise_routes_script = local.routes_to_advertise ? "" : templatefile(
    "${path.module}/scripts/advertise-routes.tftpl",
    {
      tailscale_advertise_routes                   = join(",", var.tailscale_advertise_routes),
      tailscale_advertise_routes_from_file_on_host = local.saas_routes_to_advertise ? "" : var.tailscale_advertise_routes_from_file_on_host
    }
  )
}
