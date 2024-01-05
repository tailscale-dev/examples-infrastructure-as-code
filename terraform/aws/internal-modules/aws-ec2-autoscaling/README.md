# aws-ec2-autoscaling

This module creates the following:

- an EC2 Launch Template and a userdata script to install and configure Tailscale
- an EC2 Autoscaling Group using the Launch Template with `min_size`, `max_size`, and `desired_capacity` set to `1`
- a Tailnet device key to authenticate the instance to your Tailnet

## Considerations

- Any advertised routes and exit nodes must still be approved in the Tailscale Admin Console. The code can be updated to use [Auto Approvers for routes](https://tailscale.com/kb/1018/acls/#auto-approvers-for-routes-and-exit-nodes) if this is configured in your ACLs.

## Example Usage

See the `examples` folder for complete examples.
