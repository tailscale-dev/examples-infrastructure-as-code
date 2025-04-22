# How to contribute

Contributions are welcome! That being said, this repository is not meant to contain every combination of every infrastructure as code tool, infrastructure provider, or possible deployment type available. It contains examples for the most common of each, and they are _examples_, not production-ready configurations.

## Making a contribution

- **An example** - please [open an issue](https://github.com/tailscale-dev/examples-infrastructure-as-code/issues) describing your proposed example before spending your time and resources developing the example and submitting a pull request. Contributions for unique or less common deployments may not be accepted.
- **A bug fix** - please [open an issue](https://github.com/tailscale-dev/examples-infrastructure-as-code/issues) describing the bug if one does not already exist and feel free to submit a pull request with a fix.
- **Have a question?** - please [open an issue](https://github.com/tailscale-dev/examples-infrastructure-as-code/issues) describing your contribution before spending your time and resources developing it.
- **Something else** - please [open an issue](https://github.com/tailscale-dev/examples-infrastructure-as-code/issues) describing your contribution before spending your time and resources developing it.

## Guiding principles for this repository

The examples in this repository:

- Are _examples_. They are not production-ready and don't claim to be.
- Are meant to be generally applicable. If you have a highly-specific use case, this repository is probably not the best place for it.
- Strive to follow the [style guide](#style-guide) below.

## Style guide

- Include a `README.md` file that describes the use case and the Cloud and Tailscale resources that will be created.
- Use up-to-date versions of providers, modules, and third-party libraries and avoid deprecated features or arguments of providers, modules, etc.
- Put all customizable options, such as VPC CIDR blocks, common resource tags, etc., in common variables:
    - In Terraform, use [local values](https://developer.hashicorp.com/terraform/language/values/locals) - e.g. a single `locals { }` block at the top of `main.tf`.
    - In other languages use idiomatic coding practices appropriate to the language - e.g. in TypeScript use [const declarations](https://www.typescriptlang.org/docs/handbook/variable-declarations.html#const-declarations) in as few blocks as possible.
- Prefix all provisioned resource names with `"example-${basename(path.cwd)}"`, ideally using a local variable for the prefix.
- Tag all resources with a `Name` tag matching the resource name (e.g. `"example-${basename(path.cwd)}"`).
- Use community modules for undifferentiated heavy lifting, such as cloud VPCs or virtual networks. When possible, make these modules easy to remove without requiring lots of changes throughout the rest of the example.
- Format your example code with `terraform fmt` or equivalent fo the language you're using.

### Mock Terraform example

```hcl
// All customizable parameters in locals for easy customization.
locals {
  // common name based on the directory name
  name = "example-${basename(path.cwd)}"

  // common tags used across all resources
  tags = {
    Name = local.name
  }

  // tailscale-specific arguments
  tailscale_acl_tags = [
    "tag:example-infra",
    "tag:example-exitnode",
  ]
  tailscale_set_preferences = [
    "--auto-update",
    "--ssh",
    "--advertise-connector",
    // ...
  ]

  // other arguments that are easily customized in one place
  vpc_id                         = module.vpc.vpc_id
  vpc_cidr_block                 = "10.0.80.0/22"
  vpc_public_subnet_cidr_blocks  = ["10.0.80.0/24"]
  vpc_private_subnet_cidr_blocks = ["10.0.81.0/24"]

  instance_subnet_id          = module.vpc.public_subnets[0]
  instance_security_group_ids = [fake_security_group.tailscale.id]
  instance_type               = "c7g.medium"
}

// Remove this to use your own VPC.
module "vpc" {
  source = "#url"

  // customize the name as applicable
  name = "${local.name}-primary"
  tags = merge(local.tags, {
    Name = "${local.name}-primary",
  })

  // most critical arguments sourced from locals
  cidr            = local.vpc_cidr_block
  public_subnets  = local.vpc_public_subnet_cidr_blocks
  private_subnets = local.vpc_private_subnet_cidr_blocks
}

resource "fake_security_group" "main" {
  // customize the name as applicable
  name = "${local.name}-main"
  tags = merge(local.tags, {
    Name = "${local.name}-main",
  })

  // ...
}

resource "fake_instance" "main" {
  // customize the name as applicable
  name = "${local.name}-main"
  tags = merge(local.tags, {
    Name = "${local.name}-main",
  })

  // most critical arguments sourced from locals
  subnet_id          = local.instance_subnet_id
  security_group_ids = local.instance_security_group_ids
  type               = local.instance_type

  // ...
}
```
