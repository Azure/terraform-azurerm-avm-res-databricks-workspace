provider "azurerm" {
  features {}
}

run "private_endpoint_example_plan" {
  command = plan

  assert {
    condition     = module.databricks.resource.name != null
    error_message = "Databricks workspace name should not be null"
  }

  assert {
    condition     = module.databricks.resource.sku == "premium"
    error_message = "Databricks workspace SKU should be 'premium' for private endpoint example"
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
    condition     = module.databricks.resource.custom_parameters[0].no_public_ip == true
    error_message = "No public IP should be enabled for private endpoint example"
  }

  assert {
    condition     = module.databricks.resource.custom_parameters[0].virtual_network_id == azurerm_virtual_network.this.id
    error_message = "Virtual network ID should match created VNet"
  }

  assert {
    condition     = module.databricks.resource.network_security_group_rules_required == "NoAzureDatabricksRules"
    error_message = "NSG rules should be set to NoAzureDatabricksRules for private endpoint example"
  }

  assert {
    condition     = module.databricks.resource.public_network_access_enabled == true
    error_message = "Public network access should be enabled in this example"
  }

  assert {
    condition     = length(keys(module.databricks.private_endpoints)) > 0
    error_message = "Private endpoints should be configured"
  }

  assert {
    condition     = contains(keys(module.databricks.private_endpoints), "databricks_ui_api")
    error_message = "databricks_ui_api private endpoint should be configured"
  }
}

run "private_endpoint_example_apply" {
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
    condition     = length(module.databricks.private_endpoints) > 0
    error_message = "Private endpoints should be created after apply"
  }
}