output "routes_script" {
  description = "Sript to fetch, parse, and save routes to `var.routes_file_to_append`"
  value       = local.advertise_routes_script
}
output "routes_file_to_append" {
  description = "File on the host with (sorted and distinct) routes"
  value       = var.tailscale_advertise_routes_from_file_on_host
}
