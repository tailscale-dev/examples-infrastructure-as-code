locals {
  name = var.cluster_name != "" ? var.cluster_name : "example-${basename(path.cwd)}"

  tags = merge({
    Name        = local.name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }, var.tags)
} 