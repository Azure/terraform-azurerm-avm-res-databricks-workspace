provider "azurerm" {
  features {}
}

variables {
  enable_telemetry = false
}

run "default_example_plan" {
  command = plan

  assert {
    condition     = module.databricks.resource.name != null
    error_message = "Databricks workspace name should not be null"
  }

  assert {
    condition     = module.databricks.resource.sku == "standard"
    error_message = "Databricks workspace SKU should be 'standard' for default example"
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
    condition     = module.databricks.resource.customer_managed_key_enabled == false
    error_message = "Customer managed key should be disabled for default example"
  }
}

run "default_example_apply" {
  command = apply

  assert {
    condition     = module.databricks.databricks_workspace_url != null
    error_message = "Databricks workspace URL should be populated after apply"
  }

  assert {
    condition     = module.databricks.databricks_workspace_id != null
    error_message = "Databricks workspace ID should be populated after apply"
  }
}