output "databricks_workspace_id" {
  description = "The unique identifier of the databricks workspace."
  value       = module.databricks.databricks_workspace_id
}

output "databricks_workspace_url" {
  description = "The workspace URL."
  value       = module.databricks.databricks_workspace_url
}

output "resource_group_name" {
  description = "The name of the resource group."
  value       = azurerm_resource_group.this.name
}

output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.id
}