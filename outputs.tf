output "databricks_access_connector_ids" {
  description = "Map of the id's of each Databricks Access Connector."
  value       = { for key, data in azurerm_databricks_access_connector.this : key => data.id }
}

output "databricks_access_connector_principal_ids" {
  description = "Map of the principal_id's of each Databricks Access Connector."
  value       = { for key, data in azurerm_databricks_access_connector.this : key => data.identity[0].principal_id }
}

output "databricks_id" {
  description = "The ID of the Databricks Workspace in the Azure management plane."
  value       = azapi_resource.this.id
}

output "databricks_virtual_network_peering_address_space_prefixes" {
  description = "A list of address blocks reserved for this virtual network in CIDR notation."
  value       = values(azurerm_databricks_virtual_network_peering.this)[*].address_space_prefixes
}

output "databricks_virtual_network_peering_id" {
  description = "The IDs of the internal Virtual Networks used by the DataBricks Workspace."
  value       = values(azurerm_databricks_virtual_network_peering.this)[*].id
}

output "databricks_virtual_network_peering_virtual_network_id" {
  description = "The ID of the internal Virtual Network used by the DataBricks Workspace."
  value       = values(azurerm_databricks_virtual_network_peering.this)[*].virtual_network_id
}

output "databricks_workspace_disk_encryption_set_id" {
  description = "The ID of Managed Disk Encryption Set created by the Databricks Workspace. Only populated on Hybrid compute mode workspaces with customer-managed disk encryption."
  value       = try(azapi_resource.this.output.properties.diskEncryptionSetId, null)
}

output "databricks_workspace_id" {
  description = "The unique identifier of the databricks workspace in Databricks control plane."
  value       = try(azapi_resource.this.output.properties.workspaceId, null)
}

output "databricks_workspace_managed_disk_identity" {
  description = <<DESCRIPTION
  A managed_disk_identity block as documented below

  - `principal_id` - The principal UUID for the internal databricks disks identity needed to provide access to the workspace for enabling Customer Managed Keys.
  - `tenant_id` - The UUID of the tenant where the internal databricks disks identity was created.
  - `type` - The type of the internal databricks disks identity.
  DESCRIPTION
  value = try({
    principal_id = azapi_resource.this.output.properties.managedDiskIdentity.principalId
    tenant_id    = azapi_resource.this.output.properties.managedDiskIdentity.tenantId
    type         = azapi_resource.this.output.properties.managedDiskIdentity.type
  }, null)
}

output "databricks_workspace_managed_resource_group_id" {
  description = "The ID of the Managed Resource Group created by the Databricks Workspace. Returns null when compute_mode is Serverless because Databricks does not provision a managed resource group in that mode."
  value       = try(azapi_resource.this.output.properties.managedResourceGroupId, null)
}

output "databricks_workspace_storage_account_identity" {
  description = <<DESCRIPTION
  A storage_account_identity block as documented below

  - `principal_id` - The principal UUID for the internal databricks storage account needed to provide access to the workspace for enabling Customer Managed Keys.
  - `tenant_id` - The UUID of the tenant where the internal databricks storage account was created.
  - `type` - The type of the internal databricks storage account.
  DESCRIPTION
  value = try({
    principal_id = azapi_resource.this.output.properties.storageAccountIdentity.principalId
    tenant_id    = azapi_resource.this.output.properties.storageAccountIdentity.tenantId
    type         = azapi_resource.this.output.properties.storageAccountIdentity.type
  }, null)
}

output "databricks_workspace_url" {
  description = "The workspace URL which is of the format 'adb-{workspaceId}.{random}.azuredatabricks.net'."
  value       = try(azapi_resource.this.output.properties.workspaceUrl, null)
}

output "name" {
  description = "The name of the Databricks Workspace."
  value       = azapi_resource.this.name
}

output "private_endpoints" {
  description = "A map of private endpoints. The map key is the supplied input to var.private_endpoints. The map value is the entire azurerm_private_endpoint resource."
  value       = azurerm_private_endpoint.this
}

output "resource" {
  description = "This is the full output for the resource."
  value       = azapi_resource.this
}

output "resource_id" {
  description = "The ID of the Databricks Workspace in the Azure management plane."
  value       = azapi_resource.this.id
}
