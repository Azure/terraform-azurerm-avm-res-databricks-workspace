provider "azurerm" {
  features {}
}

variables {
  enable_telemetry = false
}

run "diagnostic_settings_example_plan" {
  command = plan

  assert {
    condition     = module.databricks.resource.name != null
    error_message = "Databricks workspace name should not be null"
  }

  assert {
    condition     = module.databricks.resource.sku == "premium"
    error_message = "Databricks workspace SKU should be 'premium' for diagnostic settings example"
  }

  assert {
    condition     = module.databricks.resource.location == "uk south"
    error_message = "Databricks workspace location should be 'uk south'"
  }

  assert {
    condition     = module.databricks.resource.resource_group_name == azurerm_resource_group.this.name
    error_message = "Databricks workspace resource group should match created resource group"
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.sku == "PerGB2018"
    error_message = "Log Analytics workspace SKU should be PerGB2018"
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.retention_in_days == 30
    error_message = "Log Analytics workspace retention should be 30 days"
  }
}

run "diagnostic_settings_example_apply" {
  command = apply

  assert {
    condition     = module.databricks.databricks_workspace_url != null
    error_message = "Databricks workspace URL should be populated after apply"
  }

  assert {
    condition     = module.databricks.databricks_workspace_id != null
    error_message = "Databricks workspace ID should be populated after apply"
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.id != null
    error_message = "Log Analytics workspace ID should be populated after apply"
  }

  assert {
    condition     = output.log_analytics_workspace_id == azurerm_log_analytics_workspace.this.id
    error_message = "Output log_analytics_workspace_id should match created workspace"
  }

  assert {
    condition     = output.databricks_workspace_id != null
    error_message = "Output databricks_workspace_id should be populated"
  }
}