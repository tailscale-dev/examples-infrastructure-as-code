variable "tailscale_advertise_okta_cell_names" {
  description = "List of Okta cells to retrieve IP prefixes for - e.g. ['us_cell_1','emea_cell_2']"
  type        = set(string)
  default     = []
}

locals {
  okta_routes_script = length(var.tailscale_advertise_okta_cell_names) == 0 ? null : templatefile(
    "${path.module}/scripts/get-routes-okta.tftpl",
    {
      tailscale_advertise_okta_cell_names = var.tailscale_advertise_okta_cell_names,
      routes_file_to_append               = var.tailscale_advertise_routes_from_file_on_host,
    }
  )
}
