output "databricks_id" {
  description = "The ID of the Databricks Workspace in the Azure management plane."
  value       = azurerm_databricks_workspace.this.id
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
  description = "The ID of Managed Disk Encryption Set created by the Databricks Workspace."
  value       = azurerm_databricks_workspace.this.disk_encryption_set_id
}

output "databricks_workspace_id" {
  description = "The unique identifier of the databricks workspace in Databricks control plane."
  value       = azurerm_databricks_workspace.this.workspace_id
}

output "databricks_workspace_managed_disk_identity" {
  description = <<DESCRIPTION
  A managed_disk_identity block as documented below
  
  - `principal_id` - The principal UUID for the internal databricks disks identity needed to provide access to the workspace for enabling Customer Managed Keys.
  - `tenant_id` - The UUID of the tenant where the internal databricks disks identity was created.
  - `type` - The type of the internal databricks disks identity.
  DESCRIPTION
  value = length(azurerm_databricks_workspace.this.managed_disk_identity) > 0 ? {
    principal_id = azurerm_databricks_workspace.this.managed_disk_identity[0].principal_id
    tenant_id    = azurerm_databricks_workspace.this.managed_disk_identity[0].tenant_id
    type         = azurerm_databricks_workspace.this.managed_disk_identity[0].type
  } : null
}

output "databricks_workspace_managed_resource_group_id" {
  description = "The ID of the Managed Resource Group created by the Databricks Workspace."
  value       = azurerm_databricks_workspace.this.managed_resource_group_id
}

output "databricks_workspace_storage_account_identity" {
  description = <<DESCRIPTION
  A storage_account_identity block as documented below
  
  - `principal_id` - The principal UUID for the internal databricks storage account needed to provide access to the workspace for enabling Customer Managed Keys.
  - `tenant_id` - The UUID of the tenant where the internal databricks storage account was created.
  - `type` - The type of the internal databricks storage account.
  DESCRIPTION
  value = length(azurerm_databricks_workspace.this.storage_account_identity) > 0 ? {
    principal_id = azurerm_databricks_workspace.this.storage_account_identity[0].principal_id
    tenant_id    = azurerm_databricks_workspace.this.storage_account_identity[0].tenant_id
    type         = azurerm_databricks_workspace.this.storage_account_identity[0].type
  } : null
}

output "databricks_workspace_url" {
  description = "The workspace URL which is of the format 'adb-{workspaceId}.{random}.azuredatabricks.net'."
  value       = azurerm_databricks_workspace.this.workspace_url
}

output "private_endpoints" {
  description = "A map of private endpoints. The map key is the supplied input to var.private_endpoints. The map value is the entire azurerm_private_endpoint resource."
  value       = azurerm_private_endpoint.this
}

output "resource" {
  description = "This is the full output for the resource."
  value       = azurerm_databricks_workspace.this
}
