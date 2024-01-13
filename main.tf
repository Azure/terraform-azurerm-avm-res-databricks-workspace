resource "azurerm_databricks_workspace" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku

  load_balancer_backend_address_pool_id               = var.load_balancer_backend_address_pool_id != {} ? var.load_balancer_backend_address_pool_id : null
  managed_services_cmk_key_vault_key_id               = var.managed_services_cmk_key_vault_key_id != null ? var.managed_services_cmk_key_vault_key_id : null
  managed_disk_cmk_key_vault_key_id                   = var.managed_disk_cmk_key_vault_key_id != null ? var.managed_disk_cmk_key_vault_key_id : null
  managed_disk_cmk_rotation_to_latest_version_enabled = var.managed_disk_cmk_key_vault_key_id != null && var.managed_disk_cmk_rotation_to_latest_version_enabled != null ? var.managed_disk_cmk_rotation_to_latest_version_enabled : null
  managed_resource_group_name                         = var.managed_resource_group_name != {} ? var.managed_resource_group_name : null
  customer_managed_key_enabled                        = var.customer_managed_key_enabled != {} ? var.customer_managed_key_enabled : null
  infrastructure_encryption_enabled                   = var.infrastructure_encryption_enabled != {} ? var.infrastructure_encryption_enabled : null
  public_network_access_enabled                       = var.public_network_access_enabled != {} ? var.public_network_access_enabled : null
  network_security_group_rules_required               = var.network_security_group_rules_required != {} ? var.network_security_group_rules_required : null

  dynamic "custom_parameters" {
    for_each = var.custom_parameters != {} ? [var.custom_parameters] : []
    content {
      machine_learning_workspace_id                        = lookup(custom_parameters.value, "machine_learning_workspace_id", null)
      nat_gateway_name                                     = lookup(custom_parameters.value, "nat_gateway_name", "nat-gateway")
      public_ip_name                                       = lookup(custom_parameters.value, "public_ip_name", "nat-gw-public-ip")
      no_public_ip                                         = lookup(custom_parameters.value, "no_public_ip", false)
      public_subnet_name                                   = lookup(custom_parameters.value, "public_subnet_name", null)
      public_subnet_network_security_group_association_id  = lookup(custom_parameters.value, "public_subnet_network_security_group_association_id", null)
      private_subnet_name                                  = lookup(custom_parameters.value, "private_subnet_name", null)
      private_subnet_network_security_group_association_id = lookup(custom_parameters.value, "private_subnet_network_security_group_association_id", null)
      storage_account_name                                 = lookup(custom_parameters.value, "storage_account_name", null)
      storage_account_sku_name                             = lookup(custom_parameters.value, "storage_account_sku_name", "Standard_GRS")
      virtual_network_id                                   = lookup(custom_parameters.value, "virtual_network_id", null)
      vnet_address_prefix                                  = lookup(custom_parameters.value, "vnet_address_prefix", "10.139")
    }
  }


  tags = var.tags

}

resource "azurerm_management_lock" "this" {
  count      = var.lock.kind != "None" ? 1 : 0
  name       = coalesce(var.lock.name, "lock-${var.name}")
  scope      = azurerm_databricks_workspace.this.id
  lock_level = var.lock.kind
}

resource "azurerm_role_assignment" "this" {
  for_each                               = var.role_assignments
  scope                                  = azurerm_databricks_workspace.this.id
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  principal_id                           = each.value.principal_id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each                       = var.diagnostic_settings
  name                           = each.value.name != null ? each.value.name : "diag-${var.name}"
  target_resource_id             = azurerm_databricks_workspace.this.id
  storage_account_id             = each.value.storage_account_resource_id
  eventhub_authorization_rule_id = each.value.event_hub_authorization_rule_resource_id
  eventhub_name                  = each.value.event_hub_name
  partner_solution_id            = each.value.marketplace_partner_resource_id
  log_analytics_workspace_id     = each.value.workspace_resource_id

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

  workspace_id     = azurerm_databricks_workspace.this.id
  key_vault_key_id = var.dbfs_root_cmk_key_vault_key_id
}


resource "azurerm_databricks_virtual_network_peering" "this" {
  for_each                      = var.virtual_network_peering
  name                          = each.value.name != null ? each.value.name : "${var.name}-databricks-vnet-peer"
  resource_group_name           = each.value.resource_group_name != null ? each.value.resource_group_name : var.resource_group_name
  workspace_id                  = azurerm_databricks_workspace.this.id
  remote_address_space_prefixes = each.value.remote_address_space_prefixes
  remote_virtual_network_id     = each.value.remote_virtual_network_id
  allow_virtual_network_access  = each.value.allow_virtual_network_access != null ? each.value.allow_virtual_network_access : true
  allow_forwarded_traffic       = each.value.allow_forwarded_traffic != null ? each.value.allow_forwarded_traffic : false
  allow_gateway_transit         = each.value.allow_gateway_transit != null ? each.value.allow_gateway_transit : false
  use_remote_gateways           = each.value.use_remote_gateways != null ? each.value.use_remote_gateways : false
}

resource "azurerm_databricks_access_connector" "this" {
  for_each            = var.access_connector
  name                = each.value.name != null ? each.value.name : "${var.name}-access-connector"
  resource_group_name = each.value.resource_group_name != null ? each.value.resource_group_name : var.resource_group_name
  location            = each.value.location != null ? each.value.location : var.location

  identity {
    type         = each.value.identity != null ? each.value.identity.type : null
    identity_ids = each.value.identity != null && each.value.identity.identity_ids != null ? each.value.identity.identity_ids : []
  }

  tags = each.value.tags
}
