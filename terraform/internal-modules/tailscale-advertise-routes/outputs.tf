/**
 * See other files for vendor-specific variables/outputs - `aws.tf`, `github.tf`, etc.
 */

output "routes_script" {
  description = "Sript to fetch, parse, and save routes to `var.routes_file_to_append`"
  value = join("\n", compact([
    local.aws_routes_script,
    local.github_routes_script,
    local.okta_routes_script,
    local.advertise_routes_script,
  ]))
}
output "routes_file_to_append" {
  description = "File on the host with (sorted and distinct) routes"
  value       = var.tailscale_advertise_routes_from_file_on_host
}
