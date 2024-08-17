# saas-route-lists

Scripts to download, parse, and save various SaaS IP and domain lists to advertise via a Tailscale App Connector or Subnet Router.

## Usage

```hcl
module "tailscale-advertise-routes" {
  source = "../../internal-modules/tailscale-advertise-routes"

  tailscale_advertise_aws_service_names = ["GLOBALACCELERATOR"]
  tailscale_advertise_routes            = [module.vpc.vpc_cidr_block] # ensure initial routes list is re-added
}

module "tailscale_aws_ec2_autoscaling" {
  source = "../internal-modules/aws-ec2-autoscaling/"

  // other inputs omitted

  additional_after_scripts = [
    module.tailscale-advertise-routes.routes_script,
  ]
}
```
