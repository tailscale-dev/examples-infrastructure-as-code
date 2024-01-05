variable "tailscale_advertise_github_service_names" {
  description = "List of GitHub Services to retrieve IP prefixes for - e.g. ['web','api']"
  type        = set(string)
  default     = []
}
variable "github_domain_services" { # TODO: move to tailscale-install-scripts or separate module?
  description = "List of GitHub Services to retrieve Domains for for - e.g. ['website','packages']"
  type        = set(string)
  default     = []
}

/**
 * For routes
 */
locals {
  github_routes_script = length(var.tailscale_advertise_github_service_names) == 0 ? null : templatefile(
    "${path.module}/scripts/get-routes-github.tftpl",
    {
      tailscale_advertise_github_service_names = var.tailscale_advertise_github_service_names,
      routes_file_to_append                    = var.tailscale_advertise_routes_from_file_on_host,
    }
  )
}

/**
 * For domains
 */
data "http" "github_ip_ranges_json" {
  count = length(var.github_domain_services) == 0 ? 0 : 1
  // https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/about-githubs-ip-addresses
  url = "https://api.github.com/meta"
}

locals {
  github_ip_data = length(var.github_domain_services) == 0 ? null : jsondecode(data.http.github_ip_ranges_json[0].response_body)

  github_domains = length(var.github_domain_services) == 0 ? [] : flatten([for s in var.github_domain_services :
    local.github_ip_data.domains[s]
  ])
  github_top_level_domains = length(var.github_domain_services) == 0 ? [] : [for s in local.github_domains :
    replace(s, "/^\\*\\./", "") # strip wildcard off of domains - e.g. '*.github.com' -> 'github.com'
  ]
}
output "github_domains" {
  description = "Distinct and sorted list of domains for the provider; including wildcard and TLDs - e.g. ['*.example.com','example.com']."
  value = sort(distinct(
    concat(
      local.github_domains,
      local.github_top_level_domains,
    )
  ))
}
