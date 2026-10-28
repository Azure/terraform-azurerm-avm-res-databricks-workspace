resource "azurerm_private_endpoint" "this" {
  for_each = { for k, v in var.private_endpoints : k => v if var.private_endpoints_manage_dns_zone_group }

  location                      = each.value.location != null ? each.value.location : var.location
  name                          = each.value.name != null ? each.value.name : "pe-${var.name}-${each.key}"
  resource_group_name           = each.value.resource_group_name != null ? each.value.resource_group_name : var.resource_group_name
  subnet_id                     = each.value.subnet_resource_id
  custom_network_interface_name = each.value.network_interface_name
  tags                          = each.value.tags

  private_service_connection {
    is_manual_connection           = false
    name                           = each.value.private_service_connection_name != null ? each.value.private_service_connection_name : "pse-${var.name}-${each.key}"
    private_connection_resource_id = azapi_resource.this.id
    subresource_names              = [each.value.subresource_name]
  }

  dynamic "ip_configuration" {
    for_each = each.value.ip_configurations

    content {
      name               = ip_configuration.value.name
      private_ip_address = ip_configuration.value.private_ip_address
      member_name        = ip_configuration.value.member_name
      subresource_name   = each.value.subresource_name
    }
  }

  dynamic "private_dns_zone_group" {
    for_each = length(each.value.private_dns_zone_resource_ids) > 0 ? ["this"] : []

    content {
      name                 = each.value.private_dns_zone_group_name
      private_dns_zone_ids = each.value.private_dns_zone_resource_ids
    }
  }

  # Ensure databricks workspace is fully created before creating endpoints
  depends_on = [
    azapi_resource.this
  ]
}

resource "azurerm_private_endpoint_application_security_group_association" "this" {
  for_each = local.private_endpoint_application_security_group_associations

  application_security_group_id = each.value.asg_resource_id
  private_endpoint_id           = local.private_endpoints[each.value.pe_key].id
}

resource "azurerm_private_endpoint" "this_unmanaged_dns_zone_groups" {
  for_each = { for k, v in var.private_endpoints : k => v if !var.private_endpoints_manage_dns_zone_group }

  location                      = each.value.location != null ? each.value.location : var.location
  name                          = each.value.name != null ? each.value.name : "pe-${var.name}-${each.key}"
  resource_group_name           = each.value.resource_group_name != null ? each.value.resource_group_name : var.resource_group_name
  subnet_id                     = each.value.subnet_resource_id
  custom_network_interface_name = each.value.network_interface_name
  tags                          = each.value.tags

  private_service_connection {
    is_manual_connection           = false
    name                           = each.value.private_service_connection_name != null ? each.value.private_service_connection_name : "pse-${var.name}-${each.key}"
    private_connection_resource_id = azapi_resource.this.id
    subresource_names              = [each.value.subresource_name]
  }

  dynamic "ip_configuration" {
    for_each = each.value.ip_configurations

    content {
      name               = ip_configuration.value.name
      private_ip_address = ip_configuration.value.private_ip_address
      member_name        = ip_configuration.value.member_name
      subresource_name   = each.value.subresource_name
    }
  }

  lifecycle {
    ignore_changes = [private_dns_zone_group]
  }
}

data "azapi_resource_list" "private_endpoint_role_definitions" {
  for_each = {
    for key, assignment in local.private_endpoint_role_assignments : key => assignment
    if !strcontains(lower(assignment.role_definition_id_or_name), lower(local.role_definition_resource_substring))
  }

  parent_id = local.private_endpoints[each.value.pe_key].id
  query_parameters = {
    "$filter" = ["roleName eq '${replace(each.value.role_definition_id_or_name, "'", "''")}'"]
  }
  type                   = "Microsoft.Authorization/roleDefinitions@2022-04-01"
  response_export_values = ["value"]

  lifecycle {
    postcondition {
      condition     = length(self.output.value) == 1
      error_message = "Each private endpoint role definition name must resolve to exactly one role at the endpoint scope."
    }
  }
}

resource "random_uuid" "private_endpoint_role_assignments" {
  for_each = local.private_endpoint_role_assignments
}

resource "azapi_resource" "private_endpoint_role_assignments" {
  for_each = local.private_endpoint_role_assignments

  name      = each.value.name != null ? each.value.name : random_uuid.private_endpoint_role_assignments[each.key].result
  parent_id = local.private_endpoints[each.value.pe_key].id
  type      = var.resource_types.authorization_role_assignments
  body = {
    properties = { for key, value in {
      condition                          = each.value.condition
      conditionVersion                   = each.value.condition_version
      delegatedManagedIdentityResourceId = each.value.delegated_managed_identity_resource_id
      description                        = each.value.description
      principalId                        = each.value.principal_id
      principalType                      = each.value.principal_type != null ? each.value.principal_type : (each.value.skip_service_principal_aad_check ? "ServicePrincipal" : null)
      roleDefinitionId                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : one(data.azapi_resource_list.private_endpoint_role_definitions[each.key].output.value).id
    } : key => value if value != null }
  }
  ignore_body_changes = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  replace_triggers_refs = [
    "properties.delegatedManagedIdentityResourceId",
    "properties.principalId",
    "properties.roleDefinitionId",
  ]
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}

resource "azapi_resource" "private_endpoint_locks" {
  for_each = { for key, endpoint in var.private_endpoints : key => endpoint.lock if endpoint.lock != null }

  name      = coalesce(each.value.name, "lock-${each.value.kind}")
  parent_id = local.private_endpoints[each.key].id
  type      = var.resource_types.authorization_locks
  body = {
    properties = { for key, value in {
      level = each.value.kind
      notes = each.value.notes
    } : key => value if value != null }
  }
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  depends_on = [
    azapi_resource.private_endpoint_role_assignments,
    azurerm_private_endpoint_application_security_group_association.this,
  ]
}
