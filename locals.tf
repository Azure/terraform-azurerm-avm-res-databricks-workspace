locals {
  resource_group_location            = try(data.azurerm_resource_group.parent.location, null)
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}

locals {
  private_endpoint_application_security_group_associations = { for assoc in flatten([
    for pe_k, pe_v in var.private_endpoints : [
      for asg_k, asg_v in pe_v.application_security_group_associations : {
        asg_key         = asg_k
        pe_key          = pe_k
        asg_resource_id = asg_v
      }
    ]
  ]) : "${assoc.pe_key}-${assoc.asg_key}" => assoc }
}

# Build the Microsoft.Databricks/workspaces body.properties block.
# Hybrid is the default compute_mode to preserve behaviour from the previous
# azurerm_databricks_workspace based release. Serverless compute_mode is now
# supported (issue #128).
locals {
  is_serverless             = lower(var.compute_mode) == "serverless"
  managed_resource_group    = coalesce(var.managed_resource_group_name, "databricks-rg-${var.name}-${var.resource_group_name}")
  managed_resource_group_id = "/subscriptions/${local.subscription_id}/resourceGroups/${local.managed_resource_group}"
  subscription_id           = data.azapi_client_config.this.subscription_id
}

# Parse Key Vault key URIs of the form:
#   https://<vault>.vault.azure.net/keys/<keyname>/<keyversion>
# into the components the Microsoft.Databricks ARM API requires.
locals {
  managed_disk_key_parts = var.managed_disk_cmk_key_vault_key_id != null ? regex(
    "^(https://[^/]+/)keys/([^/]+)/([^/]+)$",
    var.managed_disk_cmk_key_vault_key_id
  ) : null
  managed_services_key_parts = var.managed_services_cmk_key_vault_key_id != null ? regex(
    "^(https://[^/]+/)keys/([^/]+)/([^/]+)$",
    var.managed_services_cmk_key_vault_key_id
  ) : null
}

# Derive the Load Balancer ID and Backend Pool name from the full backend
# pool resource ID accepted by the existing module surface.
locals {
  load_balancer_backend_address_pool_parts = var.load_balancer_backend_address_pool_id != null ? regex(
    "^(.+/loadBalancers/[^/]+)/backendAddressPools/([^/]+)$",
    var.load_balancer_backend_address_pool_id
  ) : null
}

locals {
  # Strip null entries so we send a clean body to ARM.
  workspace_custom_parameters = { for k, v in local.workspace_custom_parameters_raw : k => v if v != null }
  workspace_custom_parameters_raw = {
    amlWorkspaceId = var.custom_parameters.machine_learning_workspace_id != null ? {
      value = var.custom_parameters.machine_learning_workspace_id
    } : null
    customPrivateSubnetName = var.custom_parameters.private_subnet_name != null ? {
      value = var.custom_parameters.private_subnet_name
    } : null
    customPublicSubnetName = var.custom_parameters.public_subnet_name != null ? {
      value = var.custom_parameters.public_subnet_name
    } : null
    customVirtualNetworkId = var.custom_parameters.virtual_network_id != null ? {
      value = var.custom_parameters.virtual_network_id
    } : null
    enableNoPublicIp = var.custom_parameters.no_public_ip != null ? {
      value = var.custom_parameters.no_public_ip
    } : null
    loadBalancerBackendPoolName = local.load_balancer_backend_address_pool_parts != null ? {
      value = local.load_balancer_backend_address_pool_parts[1]
    } : null
    loadBalancerId = local.load_balancer_backend_address_pool_parts != null ? {
      value = local.load_balancer_backend_address_pool_parts[0]
    } : null
    natGatewayName = var.custom_parameters.nat_gateway_name != null ? {
      value = var.custom_parameters.nat_gateway_name
    } : null
    prepareEncryption = var.customer_managed_key_enabled ? {
      value = true
    } : null
    publicIpName = var.custom_parameters.public_ip_name != null ? {
      value = var.custom_parameters.public_ip_name
    } : null
    requireInfrastructureEncryption = var.infrastructure_encryption_enabled ? {
      value = true
    } : null
    storageAccountName = var.custom_parameters.storage_account_name != null ? {
      value = var.custom_parameters.storage_account_name
    } : null
    storageAccountSkuName = var.custom_parameters.storage_account_sku_name != null ? {
      value = var.custom_parameters.storage_account_sku_name
    } : null
    vnetAddressPrefix = var.custom_parameters.vnet_address_prefix != null ? {
      value = var.custom_parameters.vnet_address_prefix
    } : null
  }
}

locals {
  workspace_encryption = length(local.workspace_encryption_entities) > 0 ? {
    entities = local.workspace_encryption_entities
  } : null
  workspace_encryption_entities = { for k, v in local.workspace_encryption_entities_raw : k => v if v != null }
  workspace_encryption_entities_raw = {
    managedDisk     = local.workspace_encryption_managed_disk
    managedServices = local.workspace_encryption_managed_services
  }
  workspace_encryption_managed_disk = var.managed_disk_cmk_key_vault_key_id != null ? {
    keySource = "Microsoft.Keyvault"
    keyVaultProperties = {
      keyName     = local.managed_disk_key_parts[1]
      keyVaultUri = local.managed_disk_key_parts[0]
      keyVersion  = local.managed_disk_key_parts[2]
    }
    rotationToLatestKeyVersionEnabled = var.managed_disk_cmk_rotation_to_latest_version_enabled
  } : null
  workspace_encryption_managed_services = var.managed_services_cmk_key_vault_key_id != null ? {
    keySource = "Microsoft.Keyvault"
    keyVaultProperties = {
      keyName     = local.managed_services_key_parts[1]
      keyVaultUri = local.managed_services_key_parts[0]
      keyVersion  = local.managed_services_key_parts[2]
    }
  } : null
}

locals {
  workspace_enhanced_security_compliance = var.enhanced_security_compliance != null ? {
    automaticClusterUpdate = {
      value = var.enhanced_security_compliance.automatic_cluster_update_enabled ? "Enabled" : "Disabled"
    }
    complianceSecurityProfile = {
      value               = var.enhanced_security_compliance.compliance_security_profile_enabled ? "Enabled" : "Disabled"
      complianceStandards = var.enhanced_security_compliance.compliance_security_profile_standards
    }
    enhancedSecurityMonitoring = {
      value = var.enhanced_security_compliance.enhanced_security_monitoring_enabled ? "Enabled" : "Disabled"
    }
  } : null
}

locals {
  # Resolve the Access Connector ID used in the workspace body. Prefer an
  # explicitly-supplied access_connector_id. Otherwise, if access_connector_key
  # references an Access Connector created by this module, use its ID. This
  # solves the chicken-and-egg problem where the connector is created within the
  # module (issue #148) and therefore cannot be passed back in as an input.
  managed_access_connector_id  = var.access_connector_key != null ? azurerm_databricks_access_connector.this[var.access_connector_key].id : null
  resolved_access_connector_id = var.access_connector_id != null ? var.access_connector_id : local.managed_access_connector_id
  workspace_access_connector = local.resolved_access_connector_id != null ? {
    id           = local.resolved_access_connector_id
    identityType = "SystemAssigned"
  } : null
  workspace_default_catalog = var.default_catalog != null ? merge(
    {
      initialType = var.default_catalog.initial_type
    },
    var.default_catalog.initial_name != null ? { initialName = var.default_catalog.initial_name } : {}
  ) : null
}

locals {
  workspace_properties = { for k, v in local.workspace_properties_raw : k => v if v != null }
  # Built as a single object with per-attribute conditionals on is_serverless to
  # avoid the "inconsistent conditional result types" Terraform error that
  # occurs when the two ternary branches have differently-typed object values.
  workspace_properties_raw = {
    accessConnector            = local.is_serverless ? null : local.workspace_access_connector
    computeMode                = local.is_serverless ? "Serverless" : "Hybrid"
    defaultCatalog             = local.is_serverless ? null : local.workspace_default_catalog
    defaultStorageFirewall     = local.is_serverless ? null : (local.resolved_access_connector_id != null || var.default_storage_firewall_enabled ? (var.default_storage_firewall_enabled ? "Enabled" : "Disabled") : null)
    encryption                 = local.workspace_encryption
    enhancedSecurityCompliance = local.workspace_enhanced_security_compliance
    managedResourceGroupId     = local.is_serverless ? null : local.managed_resource_group_id
    parameters                 = local.is_serverless ? null : (length(local.workspace_custom_parameters) > 0 ? local.workspace_custom_parameters : null)
    publicNetworkAccess        = var.public_network_access_enabled ? "Enabled" : "Disabled"
    requiredNsgRules           = local.is_serverless ? null : var.network_security_group_rules_required
  }
}
