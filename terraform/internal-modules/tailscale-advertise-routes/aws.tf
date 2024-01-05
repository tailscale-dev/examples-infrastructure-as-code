variable "tailscale_advertise_aws_service_names" {
  description = "List of AWS Services to retrieve IP prefixes for - e.g. ['GLOBALACCELERATOR','AMAZON']"
  type        = set(string)
  default     = []
}

locals {
  aws_routes_script = length(var.tailscale_advertise_aws_service_names) == 0 ? null : templatefile(
    "${path.module}/scripts/get-routes-aws.tftpl",
    {
      tailscale_advertise_aws_service_names = var.tailscale_advertise_aws_service_names,
      routes_file_to_append                 = var.tailscale_advertise_routes_from_file_on_host,
    }
  )
}
