data "azurerm_resource_group" "parent" {
  name = var.resource_group_name
}

data "azapi_client_config" "this" {}

resource "azapi_resource" "this" {
  location  = coalesce(var.location, local.resource_group_location)
  name      = var.name
  parent_id = data.azurerm_resource_group.parent.id
  type      = "Microsoft.Databricks/workspaces@2026-01-01"
  body = {
    sku = {
      name = var.sku
    }
    properties = local.workspace_properties
  }
  create_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers   = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values = [
    "properties.workspaceId",
    "properties.workspaceUrl",
    "properties.managedResourceGroupId",
    "properties.diskEncryptionSetId",
    "properties.managedDiskIdentity",
    "properties.storageAccountIdentity",
  ]
  schema_validation_enabled = false
  tags                      = var.tags
  update_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  lifecycle {
    precondition {
      condition     = var.managed_disk_cmk_key_vault_id == null || var.managed_disk_cmk_key_vault_key_id != null
      error_message = "managed_disk_cmk_key_vault_id is set but managed_disk_cmk_key_vault_key_id is not; provide the Key Vault key URI as well."
    }
    precondition {
      condition     = var.managed_services_cmk_key_vault_id == null || var.managed_services_cmk_key_vault_key_id != null
      error_message = "managed_services_cmk_key_vault_id is set but managed_services_cmk_key_vault_key_id is not; provide the Key Vault key URI as well."
    }
  }
}

resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azapi_resource.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azapi_resource.this.id
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
  target_resource_id             = azapi_resource.this.id
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
}

resource "azurerm_databricks_workspace_root_dbfs_customer_managed_key" "this" {
  count = var.customer_managed_key_enabled ? 1 : 0

  key_vault_key_id = var.dbfs_root_cmk_key_vault_key_id
  workspace_id     = azapi_resource.this.id
}


resource "azurerm_databricks_virtual_network_peering" "this" {
  for_each = var.virtual_network_peering

  name                          = each.value.name != null ? each.value.name : "${var.name}-databricks-vnet-peer"
  remote_address_space_prefixes = each.value.remote_address_space_prefixes
  remote_virtual_network_id     = each.value.remote_virtual_network_id
  resource_group_name           = each.value.resource_group_name != null ? each.value.resource_group_name : var.resource_group_name
  workspace_id                  = azapi_resource.this.id
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
