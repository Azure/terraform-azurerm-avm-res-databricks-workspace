mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      client_id                = "00000000-0000-0000-0000-000000000001"
      object_id                = "00000000-0000-0000-0000-000000000002"
      subscription_id          = "00000000-0000-0000-0000-000000000003"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000003"
      tenant_id                = "00000000-0000-0000-0000-000000000004"
    }
  }

  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-unit/providers/Microsoft.Databricks/workspaces/unit-databricks"
    }
  }

  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        value = [{
          id = "/subscriptions/00000000-0000-0000-0000-000000000003/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        }]
      }
    }
  }
}

mock_provider "azurerm" {
  mock_resource "azurerm_private_endpoint" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-unit/providers/Microsoft.Network/privateEndpoints/unit"
    }
  }

  mock_data "azurerm_resource_group" {
    defaults = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-unit"
      location = "westus"
    }
  }
}

mock_provider "random" {
  mock_resource "random_uuid" {
    defaults = {
      result = "00000000-0000-0000-0000-000000000005"
    }
  }
}

mock_provider "terraform" {
  mock_resource "terraform_data" {
    defaults = {
      id = "00000000-0000-0000-0000-000000000006"
    }
  }
}

variables {
  location            = "eastus"
  name                = "unit-databricks"
  resource_group_name = "rg-unit"
  sku                 = "premium"
}

run "default_no_endpoints" {
  command = apply

  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }

  assert {
    condition = (
      length(azurerm_private_endpoint.this) == 0 &&
      length(azurerm_private_endpoint.this_unmanaged_dns_zone_groups) == 0 &&
      length(output.private_endpoints) == 0 &&
      length(azurerm_private_endpoint_application_security_group_association.this) == 0 &&
      length(azapi_resource.private_endpoint_role_assignments) == 0 &&
      length(azapi_resource.private_endpoint_locks) == 0 &&
      length(random_uuid.private_endpoint_role_assignments) == 0 &&
      length(data.azapi_resource_list.private_endpoint_role_definitions) == 0
    )
    error_message = "Omitted private endpoints and optional extensions must not create resources or role lookups."
  }

  assert {
    condition = (
      azapi_resource.this.name == var.name &&
      azapi_resource.this.location == var.location &&
      azapi_resource.this.parent_id == data.azurerm_resource_group.parent.id &&
      azapi_resource.this.body.sku.name == var.sku &&
      azapi_resource.this.body.properties.computeMode == "Hybrid" &&
      output.resource_id == azapi_resource.this.id &&
      output.databricks_id == azapi_resource.this.id
    )
    error_message = "The existing workspace defaults and ID outputs must be preserved."
  }

  assert {
    condition = (
      length(terraform_data.telemetry) == 1 &&
      length(azapi_resource.telemetry) == 1 &&
      azapi_resource.telemetry[0].type == "Microsoft.Resources/deployments@2025-04-01" &&
      azapi_resource.telemetry[0].location == var.location &&
      azapi_resource.telemetry[0].parent_id == data.azapi_client_config.telemetry[0].subscription_resource_id &&
      startswith(azapi_resource.telemetry[0].name, "${jsondecode(file("metadata.json")).telemetryIdPrefix}.") &&
      length(azapi_resource.telemetry[0].name) <= 64 &&
      length(azapi_resource.telemetry[0].body.properties.template.resources) == 0
    )
    error_message = "Default telemetry must be a fully mocked, metadata-backed empty deployment in the selected location."
  }
}

run "telemetry_disabled" {
  command = apply

  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }

  variables {
    enable_telemetry = false
  }

  assert {
    condition = (
      length(terraform_data.telemetry) == 0 &&
      length(azapi_resource.telemetry) == 0 &&
      length(data.azapi_client_config.telemetry) == 0 &&
      length(output.private_endpoints) == 0
    )
    error_message = "Disabling telemetry must remove both telemetry resources and its client lookup."
  }
}

run "managed_endpoints_and_extensions" {
  command = apply

  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }

  variables {
    private_endpoints = {
      ui = {
        name                            = "ui-private-endpoint"
        subnet_resource_id              = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/unit/subnets/endpoints"
        subresource_name                = "databricks_ui_api"
        location                        = "westus2"
        resource_group_name             = "rg-endpoints"
        private_service_connection_name = "ui-connection"
        network_interface_name          = "ui-nic"
        tags                            = { purpose = "private-link" }
        private_dns_zone_group_name     = "workspace-dns"
        private_dns_zone_resource_ids   = ["/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.azuredatabricks.net"]
        application_security_group_associations = {
          client = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/applicationSecurityGroups/ui-clients"
        }
        ip_configurations = {
          primary = {
            name               = "ui-static"
            private_ip_address = "10.0.3.5"
            member_name        = "databricks_ui_api"
          }
        }
        role_assignments = {
          reader = {
            name                                   = "00000000-0000-0000-0000-000000000007"
            role_definition_id_or_name             = "/subscriptions/00000000-0000-0000-0000-000000000003/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
            principal_id                           = "00000000-0000-0000-0000-000000000008"
            description                            = "Private endpoint reader"
            principal_type                         = "ServicePrincipal"
            skip_service_principal_aad_check       = true
            condition                              = "!(ActionMatches{'Microsoft.Network/privateEndpoints/write'})"
            condition_version                      = "2.0"
            delegated_managed_identity_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-unit/providers/Microsoft.ManagedIdentity/userAssignedIdentities/delegated"
          }
        }
        lock = {
          kind  = "ReadOnly"
          notes = "Protect the endpoint after configuring its extensions."
        }
      }
      auth = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/unit/subnets/endpoints"
        subresource_name   = "browser_authentication"
      }
    }
  }

  override_resource {
    target = azurerm_private_endpoint.this["ui"]
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-endpoints/providers/Microsoft.Network/privateEndpoints/ui-private-endpoint"
    }
  }

  assert {
    condition = (
      length(azurerm_private_endpoint.this) == 2 &&
      length(azurerm_private_endpoint.this_unmanaged_dns_zone_groups) == 0 &&
      jsonencode(output.private_endpoints) == jsonencode(azurerm_private_endpoint.this)
    )
    error_message = "Managed endpoints must keep their existing resource addresses and complete output shape."
  }

  assert {
    condition = (
      azurerm_private_endpoint.this["ui"].location == "westus2" &&
      azurerm_private_endpoint.this["ui"].resource_group_name == "rg-endpoints" &&
      azurerm_private_endpoint.this["ui"].name == "ui-private-endpoint" &&
      azurerm_private_endpoint.this["ui"].custom_network_interface_name == "ui-nic" &&
      azurerm_private_endpoint.this["ui"].tags.purpose == "private-link" &&
      azurerm_private_endpoint.this["auth"].location == var.location &&
      azurerm_private_endpoint.this["auth"].resource_group_name == var.resource_group_name &&
      azurerm_private_endpoint.this["auth"].name == "pe-${var.name}-auth" &&
      azurerm_private_endpoint.this["auth"].private_service_connection[0].name == "pse-${var.name}-auth" &&
      length(azurerm_private_endpoint.this["auth"].ip_configuration) == 0 &&
      length(azurerm_private_endpoint.this["auth"].private_dns_zone_group) == 0
    )
    error_message = "Authored endpoint overrides and omitted optional settings must retain their existing behavior."
  }

  assert {
    condition = (
      azurerm_private_endpoint.this["ui"].private_service_connection[0].name == "ui-connection" &&
      azurerm_private_endpoint.this["ui"].private_service_connection[0].private_connection_resource_id == azapi_resource.this.id &&
      azurerm_private_endpoint.this["ui"].private_service_connection[0].subresource_names == tolist(["databricks_ui_api"]) &&
      azurerm_private_endpoint.this["auth"].private_service_connection[0].subresource_names == tolist(["browser_authentication"]) &&
      one(azurerm_private_endpoint.this["ui"].ip_configuration).name == "ui-static" &&
      one(azurerm_private_endpoint.this["ui"].ip_configuration).member_name == "databricks_ui_api" &&
      one(azurerm_private_endpoint.this["ui"].ip_configuration).subresource_name == "databricks_ui_api" &&
      one(azurerm_private_endpoint.this["ui"].ip_configuration).private_ip_address == "10.0.3.5" &&
      azurerm_private_endpoint.this["ui"].private_dns_zone_group[0].name == "workspace-dns" &&
      toset(azurerm_private_endpoint.this["ui"].private_dns_zone_group[0].private_dns_zone_ids) == var.private_endpoints["ui"].private_dns_zone_resource_ids &&
      azurerm_private_endpoint_application_security_group_association.this["ui-client"].private_endpoint_id == azurerm_private_endpoint.this["ui"].id &&
      azurerm_private_endpoint_application_security_group_association.this["ui-client"].application_security_group_id == var.private_endpoints["ui"].application_security_group_associations["client"]
    )
    error_message = "Managed static IPs, selected groups, DNS zones and ASG associations must use the declared endpoint contract."
  }

  assert {
    condition = (
      length(azapi_resource.private_endpoint_role_assignments) == 1 &&
      length(data.azapi_resource_list.private_endpoint_role_definitions) == 0 &&
      toset(keys(random_uuid.private_endpoint_role_assignments)) == toset([jsonencode(["ui", "reader"])]) &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["ui", "reader"])].name == var.private_endpoints["ui"].role_assignments["reader"].name &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["ui", "reader"])].parent_id == azurerm_private_endpoint.this["ui"].id &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["ui", "reader"])].type == var.resource_types.authorization_role_assignments &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["ui", "reader"])].body.properties.roleDefinitionId == var.private_endpoints["ui"].role_assignments["reader"].role_definition_id_or_name &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["ui", "reader"])].body.properties.principalId == var.private_endpoints["ui"].role_assignments["reader"].principal_id &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["ui", "reader"])].body.properties.principalType == "ServicePrincipal" &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["ui", "reader"])].body.properties.description == "Private endpoint reader" &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["ui", "reader"])].body.properties.condition == var.private_endpoints["ui"].role_assignments["reader"].condition &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["ui", "reader"])].body.properties.conditionVersion == "2.0" &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["ui", "reader"])].body.properties.delegatedManagedIdentityResourceId == var.private_endpoints["ui"].role_assignments["reader"].delegated_managed_identity_resource_id &&
      contains(azapi_resource.private_endpoint_role_assignments[jsonencode(["ui", "reader"])].replace_triggers_refs, "properties.delegatedManagedIdentityResourceId") &&
      contains(azapi_resource.private_endpoint_role_assignments[jsonencode(["ui", "reader"])].replace_triggers_refs, "properties.principalId") &&
      contains(azapi_resource.private_endpoint_role_assignments[jsonencode(["ui", "reader"])].replace_triggers_refs, "properties.roleDefinitionId")
    )
    error_message = "Every authored role assignment property must reach the endpoint-scoped AzAPI extension without unnecessary lookups."
  }

  assert {
    condition = (
      length(azapi_resource.private_endpoint_locks) == 1 &&
      azapi_resource.private_endpoint_locks["ui"].name == "lock-ReadOnly" &&
      azapi_resource.private_endpoint_locks["ui"].parent_id == azurerm_private_endpoint.this["ui"].id &&
      azapi_resource.private_endpoint_locks["ui"].type == var.resource_types.authorization_locks &&
      azapi_resource.private_endpoint_locks["ui"].body.properties.level == "ReadOnly" &&
      azapi_resource.private_endpoint_locks["ui"].body.properties.notes == var.private_endpoints["ui"].lock.notes
    )
    error_message = "Only requested endpoint locks must be created, with the selected level and notes."
  }
}

run "unmanaged_endpoints_and_extensions" {
  command = apply

  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }

  variables {
    private_endpoints_manage_dns_zone_group = false
    private_endpoints = {
      auth = {
        subnet_resource_id            = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/unit/subnets/endpoints"
        subresource_name              = "browser_authentication"
        location                      = "centralus"
        resource_group_name           = "rg-external"
        private_dns_zone_resource_ids = ["/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.azuredatabricks.net"]
        application_security_group_associations = {
          client = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/applicationSecurityGroups/auth-clients"
        }
        ip_configurations = {
          primary = {
            name               = "auth-static"
            private_ip_address = "10.0.3.6"
            member_name        = "auth-member"
          }
        }
        role_assignments = {
          reader = {
            role_definition_id_or_name       = "Reader"
            principal_id                     = "00000000-0000-0000-0000-000000000009"
            skip_service_principal_aad_check = true
          }
          explicit = {
            name                       = "00000000-0000-0000-0000-000000000010"
            role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000003/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
            principal_id               = "00000000-0000-0000-0000-000000000011"
          }
        }
        lock = {
          name = "auth-lock"
          kind = "CanNotDelete"
        }
      }
      ui = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/unit/subnets/endpoints"
        subresource_name   = "databricks_ui_api"
      }
    }
    resource_types = {
      authorization_locks = "Microsoft.Authorization/locks@2016-09-01"
    }
    retry = {
      error_message_regex  = ["ScopeLocked"]
      interval_seconds     = 5
      max_interval_seconds = 30
    }
    timeouts = {
      create = "30m"
      read   = "10m"
      update = "20m"
      delete = "15m"
    }
  }

  override_resource {
    target = azurerm_private_endpoint.this_unmanaged_dns_zone_groups["auth"]
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-external/providers/Microsoft.Network/privateEndpoints/pe-unit-databricks-auth"
    }
  }

  assert {
    condition = (
      length(azurerm_private_endpoint.this) == 0 &&
      length(azurerm_private_endpoint.this_unmanaged_dns_zone_groups) == 2 &&
      jsonencode(output.private_endpoints) == jsonencode(azurerm_private_endpoint.this_unmanaged_dns_zone_groups) &&
      length(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["auth"].private_dns_zone_group) == 0 &&
      azurerm_private_endpoint_application_security_group_association.this["auth-client"].private_endpoint_id == azurerm_private_endpoint.this_unmanaged_dns_zone_groups["auth"].id &&
      azurerm_private_endpoint_application_security_group_association.this["auth-client"].application_security_group_id == var.private_endpoints["auth"].application_security_group_associations["client"]
    )
    error_message = "Unmanaged endpoints must keep their addresses and serve outputs and ASG associations without managing DNS groups."
  }

  assert {
    condition = (
      azurerm_private_endpoint.this_unmanaged_dns_zone_groups["auth"].location == "centralus" &&
      azurerm_private_endpoint.this_unmanaged_dns_zone_groups["auth"].resource_group_name == "rg-external" &&
      azurerm_private_endpoint.this_unmanaged_dns_zone_groups["ui"].location == var.location &&
      azurerm_private_endpoint.this_unmanaged_dns_zone_groups["ui"].resource_group_name == var.resource_group_name &&
      azurerm_private_endpoint.this_unmanaged_dns_zone_groups["auth"].private_service_connection[0].subresource_names == tolist(["browser_authentication"]) &&
      one(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["auth"].ip_configuration).member_name == "auth-member" &&
      one(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["auth"].ip_configuration).subresource_name == "browser_authentication" &&
      one(azurerm_private_endpoint.this_unmanaged_dns_zone_groups["auth"].ip_configuration).private_ip_address == "10.0.3.6"
    )
    error_message = "Unmanaged endpoints must preserve location overrides and pass through distinct static member and endpoint group selections."
  }

  assert {
    condition = (
      length(azapi_resource.private_endpoint_role_assignments) == 2 &&
      toset(keys(random_uuid.private_endpoint_role_assignments)) == toset([jsonencode(["auth", "reader"]), jsonencode(["auth", "explicit"])]) &&
      length(data.azapi_resource_list.private_endpoint_role_definitions) == 1 &&
      data.azapi_resource_list.private_endpoint_role_definitions[jsonencode(["auth", "reader"])].parent_id == azurerm_private_endpoint.this_unmanaged_dns_zone_groups["auth"].id &&
      data.azapi_resource_list.private_endpoint_role_definitions[jsonencode(["auth", "reader"])].query_parameters["$filter"] == tolist(["roleName eq 'Reader'"]) &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["auth", "reader"])].name == random_uuid.private_endpoint_role_assignments[jsonencode(["auth", "reader"])].result &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["auth", "explicit"])].name == var.private_endpoints["auth"].role_assignments["explicit"].name &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["auth", "reader"])].parent_id == azurerm_private_endpoint.this_unmanaged_dns_zone_groups["auth"].id &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["auth", "reader"])].body.properties.roleDefinitionId == one(data.azapi_resource_list.private_endpoint_role_definitions[jsonencode(["auth", "reader"])].output.value).id &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["auth", "reader"])].body.properties.principalType == "ServicePrincipal" &&
      !contains(keys(azapi_resource.private_endpoint_role_assignments[jsonencode(["auth", "explicit"])].body.properties), "principalType") &&
      !contains(keys(azapi_resource.private_endpoint_role_assignments[jsonencode(["auth", "explicit"])].body.properties), "condition")
    )
    error_message = "Unmanaged endpoint roles must resolve names at the correct scope, select generated names only when omitted, and honor principal-type defaults."
  }

  assert {
    condition = (
      length(azapi_resource.private_endpoint_locks) == 1 &&
      azapi_resource.private_endpoint_locks["auth"].name == "auth-lock" &&
      azapi_resource.private_endpoint_locks["auth"].parent_id == azurerm_private_endpoint.this_unmanaged_dns_zone_groups["auth"].id &&
      azapi_resource.private_endpoint_locks["auth"].body.properties.level == "CanNotDelete" &&
      !contains(keys(azapi_resource.private_endpoint_locks["auth"].body.properties), "notes") &&
      azapi_resource.private_endpoint_locks["auth"].type == "Microsoft.Authorization/locks@2016-09-01" &&
      azapi_resource.private_endpoint_locks["auth"].retry.error_message_regex == var.retry.error_message_regex &&
      azapi_resource.private_endpoint_locks["auth"].retry.interval_seconds == 5 &&
      azapi_resource.private_endpoint_locks["auth"].retry.max_interval_seconds == 30 &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["auth", "reader"])].retry.error_message_regex == var.retry.error_message_regex &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["auth", "reader"])].retry.interval_seconds == 5 &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["auth", "reader"])].retry.max_interval_seconds == 30 &&
      azapi_resource.private_endpoint_locks["auth"].timeouts.create == "30m" &&
      azapi_resource.private_endpoint_locks["auth"].timeouts.read == "10m" &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["auth", "reader"])].timeouts.update == "20m" &&
      azapi_resource.private_endpoint_role_assignments[jsonencode(["auth", "reader"])].timeouts.delete == "15m" &&
      azapi_resource.this.retry.error_message_regex == var.retry.error_message_regex &&
      azapi_resource.this.retry.interval_seconds == 5 &&
      azapi_resource.this.retry.max_interval_seconds == 30 &&
      azapi_resource.this.timeouts.create == "30m"
    )
    error_message = "Unmanaged endpoint extensions must honor lock names, omitted notes and the shared AzAPI control interfaces."
  }
}

run "missing_group_rejected" {
  command = plan
  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }
  variables {
    private_endpoints = {
      endpoint = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/unit/subnets/endpoints"
      }
    }
  }
  expect_failures = [var.private_endpoints]
}

run "empty_group_rejected" {
  command = plan
  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }
  variables {
    private_endpoints = {
      endpoint = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/unit/subnets/endpoints"
        subresource_name   = " "
      }
    }
  }
  expect_failures = [var.private_endpoints]
}

run "missing_static_member_rejected" {
  command = plan
  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }
  variables {
    private_endpoints = {
      endpoint = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/unit/subnets/endpoints"
        subresource_name   = "databricks_ui_api"
        ip_configurations = {
          primary = { name = "static", private_ip_address = "10.0.3.5" }
        }
      }
    }
  }
  expect_failures = [var.private_endpoints]
}

run "empty_static_member_rejected" {
  command = plan
  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }
  variables {
    private_endpoints_manage_dns_zone_group = false
    private_endpoints = {
      endpoint = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/unit/subnets/endpoints"
        subresource_name   = "browser_authentication"
        ip_configurations = {
          primary = { name = "static", private_ip_address = "10.0.3.5", member_name = "" }
        }
      }
    }
  }
  expect_failures = [var.private_endpoints]
}

run "invalid_lock_rejected" {
  command = plan
  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }
  variables {
    private_endpoints = {
      endpoint = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/unit/subnets/endpoints"
        subresource_name   = "databricks_ui_api"
        lock               = { kind = "None" }
      }
    }
  }
  expect_failures = [var.private_endpoints]
}

run "incompatible_principal_type_rejected" {
  command = plan
  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }
  variables {
    private_endpoints = {
      endpoint = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/unit/subnets/endpoints"
        subresource_name   = "databricks_ui_api"
        role_assignments = {
          reader = {
            role_definition_id_or_name       = "Reader"
            principal_id                     = "00000000-0000-0000-0000-000000000009"
            principal_type                   = "User"
            skip_service_principal_aad_check = true
          }
        }
      }
    }
  }
  expect_failures = [var.private_endpoints]
}

run "invalid_subnet_rejected" {
  command = plan
  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }
  variables {
    private_endpoints = {
      endpoint = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/unit"
        subresource_name   = "databricks_ui_api"
      }
    }
  }
  expect_failures = [var.private_endpoints]
}

run "invalid_dns_zone_rejected" {
  command = plan
  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }
  variables {
    private_endpoints = {
      endpoint = {
        subnet_resource_id            = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/unit/subnets/endpoints"
        subresource_name              = "databricks_ui_api"
        private_dns_zone_resource_ids = ["not-a-dns-zone-id"]
      }
    }
  }
  expect_failures = [var.private_endpoints]
}

run "invalid_asg_rejected" {
  command = plan
  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }
  variables {
    private_endpoints = {
      endpoint = {
        subnet_resource_id                      = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/unit/subnets/endpoints"
        subresource_name                        = "databricks_ui_api"
        application_security_group_associations = { client = "not-an-asg-id" }
      }
    }
  }
  expect_failures = [var.private_endpoints]
}

run "invalid_delegated_identity_rejected" {
  command = plan
  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }
  variables {
    private_endpoints = {
      endpoint = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/unit/subnets/endpoints"
        subresource_name   = "databricks_ui_api"
        role_assignments = {
          reader = {
            role_definition_id_or_name             = "Reader"
            principal_id                           = "00000000-0000-0000-0000-000000000009"
            delegated_managed_identity_resource_id = "not-an-identity-id"
          }
        }
      }
    }
  }
  expect_failures = [var.private_endpoints]
}

run "missing_role_definition_rejected" {
  command   = apply
  state_key = "missing_role_definition"
  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }
  variables {
    private_endpoints = {
      endpoint = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/unit/subnets/endpoints"
        subresource_name   = "databricks_ui_api"
        role_assignments = {
          reader = {
            role_definition_id_or_name = "Missing role"
            principal_id               = "00000000-0000-0000-0000-000000000009"
          }
        }
      }
    }
  }
  override_data {
    target = data.azapi_resource_list.private_endpoint_role_definitions["[\"endpoint\",\"reader\"]"]
    values = {
      output = { value = [] }
    }
  }
  expect_failures = [data.azapi_resource_list.private_endpoint_role_definitions]
}

run "cleanup_missing_role_definition" {
  command   = apply
  state_key = "missing_role_definition"
  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }
  variables {
    private_endpoints = {}
  }
  assert {
    condition = (
      length(azurerm_private_endpoint.this) == 0 &&
      length(azapi_resource.private_endpoint_role_assignments) == 0 &&
      length(random_uuid.private_endpoint_role_assignments) == 0
    )
    error_message = "The failed missing-role test must leave no endpoint role resources for teardown."
  }
}

run "ambiguous_role_definition_rejected" {
  command   = apply
  state_key = "ambiguous_role_definition"
  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }
  variables {
    private_endpoints = {
      endpoint = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/unit/subnets/endpoints"
        subresource_name   = "databricks_ui_api"
        role_assignments = {
          reader = {
            role_definition_id_or_name = "Ambiguous role"
            principal_id               = "00000000-0000-0000-0000-000000000009"
          }
        }
      }
    }
  }
  override_data {
    target = data.azapi_resource_list.private_endpoint_role_definitions["[\"endpoint\",\"reader\"]"]
    values = {
      output = {
        value = [
          { id = "/subscriptions/00000000-0000-0000-0000-000000000003/providers/Microsoft.Authorization/roleDefinitions/00000000-0000-0000-0000-000000000012" },
          { id = "/subscriptions/00000000-0000-0000-0000-000000000003/providers/Microsoft.Authorization/roleDefinitions/00000000-0000-0000-0000-000000000013" },
        ]
      }
    }
  }
  expect_failures = [data.azapi_resource_list.private_endpoint_role_definitions]
}

run "cleanup_ambiguous_role_definition" {
  command   = apply
  state_key = "ambiguous_role_definition"
  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }
  variables {
    private_endpoints = {}
  }
  assert {
    condition = (
      length(azurerm_private_endpoint.this) == 0 &&
      length(azapi_resource.private_endpoint_role_assignments) == 0 &&
      length(random_uuid.private_endpoint_role_assignments) == 0
    )
    error_message = "The failed ambiguous-role test must leave no endpoint role resources for teardown."
  }
}
