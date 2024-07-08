data "azurerm_resource_group" "parent" {
  name = var.resource_group_name
}

resource "azurerm_databricks_workspace" "this" {
  location                                            = coalesce(var.location, local.resource_group_location)
  name                                                = var.name
  resource_group_name                                 = var.resource_group_name
  sku                                                 = var.sku
  customer_managed_key_enabled                        = try(var.customer_managed_key_enabled, null)
  infrastructure_encryption_enabled                   = try(var.infrastructure_encryption_enabled, null)
  load_balancer_backend_address_pool_id               = try(var.load_balancer_backend_address_pool_id, null)
  managed_disk_cmk_key_vault_key_id                   = try(var.managed_disk_cmk_key_vault_key_id, null)
  managed_disk_cmk_rotation_to_latest_version_enabled = var.managed_disk_cmk_key_vault_key_id != null && var.managed_disk_cmk_rotation_to_latest_version_enabled != null ? var.managed_disk_cmk_rotation_to_latest_version_enabled : null
  managed_resource_group_name                         = try(var.managed_resource_group_name, null)
  managed_services_cmk_key_vault_key_id               = try(var.managed_services_cmk_key_vault_key_id, null)
  network_security_group_rules_required               = try(var.network_security_group_rules_required, null)
  public_network_access_enabled                       = try(var.public_network_access_enabled, null)
  tags                                                = var.tags

  dynamic "custom_parameters" {
    for_each = var.custom_parameters != {} ? [var.custom_parameters] : []
    content {
      machine_learning_workspace_id                        = lookup(custom_parameters.value, "machine_learning_workspace_id", null)
      nat_gateway_name                                     = lookup(custom_parameters.value, "nat_gateway_name", "nat-gateway")
      no_public_ip                                         = lookup(custom_parameters.value, "no_public_ip", false)
      private_subnet_name                                  = lookup(custom_parameters.value, "private_subnet_name", null)
      private_subnet_network_security_group_association_id = lookup(custom_parameters.value, "private_subnet_network_security_group_association_id", null)
      public_ip_name                                       = lookup(custom_parameters.value, "public_ip_name", "nat-gw-public-ip")
      public_subnet_name                                   = lookup(custom_parameters.value, "public_subnet_name", null)
      public_subnet_network_security_group_association_id  = lookup(custom_parameters.value, "public_subnet_network_security_group_association_id", null)
      storage_account_name                                 = lookup(custom_parameters.value, "storage_account_name", null)
      storage_account_sku_name                             = lookup(custom_parameters.value, "storage_account_sku_name", "Standard_GRS")
      virtual_network_id                                   = lookup(custom_parameters.value, "virtual_network_id", null)
      vnet_address_prefix                                  = lookup(custom_parameters.value, "vnet_address_prefix", "10.139")
    }
  }
}

resource "azurerm_management_lock" "this" {
  count = var.lock.kind != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.name}")
  scope      = azurerm_databricks_workspace.this.id
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azurerm_databricks_workspace.this.id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = var.diagnostic_settings

  name                           = each.value.name != null ? each.value.name : "diag-${var.name}"
  target_resource_id             = azurerm_databricks_workspace.this.id
  eventhub_authorization_rule_id = each.value.event_hub_authorization_rule_resource_id
  eventhub_name                  = each.value.event_hub_name
  log_analytics_workspace_id     = each.value.workspace_resource_id
  partner_solution_id            = each.value.marketplace_partner_resource_id
  storage_account_id             = each.value.storage_account_resource_id

  dynamic "enabled_log" {
    for_each = each.value.log_categories
    content {
      category = enabled_log.value
    }
  }
  dynamic "enabled_log" {
    for_each = each.value.log_groups
    content {
      category_group = enabled_log.value
    }
  }
  dynamic "metric" {
    for_each = each.value.metric_categories
    content {
      category = metric.value
    }
  }
}

resource "azurerm_databricks_workspace_root_dbfs_customer_managed_key" "this" {
  count = var.customer_managed_key_enabled ? 1 : 0

  key_vault_key_id = var.dbfs_root_cmk_key_vault_key_id
  workspace_id     = azurerm_databricks_workspace.this.id
}


resource "azurerm_databricks_virtual_network_peering" "this" {
  for_each = var.virtual_network_peering

  name                          = each.value.name != null ? each.value.name : "${var.name}-databricks-vnet-peer"
  remote_address_space_prefixes = each.value.remote_address_space_prefixes
  remote_virtual_network_id     = each.value.remote_virtual_network_id
  resource_group_name           = each.value.resource_group_name != null ? each.value.resource_group_name : var.resource_group_name
  workspace_id                  = azurerm_databricks_workspace.this.id
  allow_forwarded_traffic       = each.value.allow_forwarded_traffic != null ? each.value.allow_forwarded_traffic : false
  allow_gateway_transit         = each.value.allow_gateway_transit != null ? each.value.allow_gateway_transit : false
  allow_virtual_network_access  = each.value.allow_virtual_network_access != null ? each.value.allow_virtual_network_access : true
  use_remote_gateways           = each.value.use_remote_gateways != null ? each.value.use_remote_gateways : false
}

resource "azurerm_databricks_access_connector" "this" {
  for_each = var.access_connector

  location            = each.value.location != null ? each.value.location : var.location
  name                = each.value.name != null ? each.value.name : "${var.name}-access-connector"
  resource_group_name = each.value.resource_group_name != null ? each.value.resource_group_name : var.resource_group_name
  tags                = each.value.tags

  identity {
    type         = each.value.identity != null ? each.value.identity.type : null
    identity_ids = each.value.identity != null && each.value.identity.identity_ids != null ? each.value.identity.identity_ids : []
  }
}
