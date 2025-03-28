# AKS Resources

resource "azurerm_resource_group" "aks" {
  name     = "${local.name}-rg"
  location = var.location
  tags     = local.tags
}

module "vpc" {
  source = "../internal-modules/azure-network"

  name = local.name
  tags = local.tags

  location            = var.location
  resource_group_name = azurerm_resource_group.aks.name

  cidrs                            = var.vnet_address_space
  subnet_cidrs                     = var.subnet_address_prefixes
  subnet_name_public               = "aks-nodes"
  subnet_name_private              = "aks-private"
  subnet_name_private_dns_resolver = "dns-resolver"
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.name
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = local.name
  kubernetes_version  = var.kubernetes_version

  # Add node resource group name
  node_resource_group = "${local.name}-node-rg"

  default_node_pool {
    name                = "default"
    vm_size             = var.vm_size
    vnet_subnet_id      = module.vpc.public_subnet_id
    enable_auto_scaling = var.enable_auto_scaling
    min_count           = var.min_count
    max_count           = var.max_count
    os_disk_size_gb     = 50
    zones               = [1, 2, 3]
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
    load_balancer_sku = "standard"
  }

  # Use oms_agent addon directly instead of addon_profile
  dynamic "oms_agent" {
    for_each = var.enable_log_analytics_workspace ? [1] : []
    content {
      log_analytics_workspace_id = azurerm_log_analytics_workspace.aks[0].id
    }
  }

  tags = local.tags
}

# Conditionally create Log Analytics workspace if monitoring is enabled
resource "azurerm_log_analytics_workspace" "aks" {
  count               = var.enable_log_analytics_workspace ? 1 : 0
  name                = "${local.name}-logs"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_in_days
  tags                = local.tags
} 