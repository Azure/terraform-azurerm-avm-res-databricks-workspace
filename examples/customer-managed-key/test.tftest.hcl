provider "azurerm" {
  features {}
}

run "customer_managed_key_example_plan" {
  command = plan

  assert {
    condition     = module.databricks.resource.name != null
    error_message = "Databricks workspace name should not be null"
  }

  assert {
    condition     = module.databricks.resource.sku == "premium"
    error_message = "Databricks workspace SKU should be 'premium' for customer managed key example"
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
    condition     = module.databricks.resource.customer_managed_key_enabled == true
    error_message = "Customer managed key should be enabled for customer managed key example"
  }

  assert {
    condition     = module.databricks.resource.managed_disk_cmk_key_vault_key_id == azurerm_key_vault_key.managed_disk_cmk.id
    error_message = "Managed disk CMK key vault key ID should match created key"
  }

  assert {
    condition     = module.databricks.resource.managed_services_cmk_key_vault_key_id == azurerm_key_vault_key.cmkms.id
    error_message = "Managed services CMK key vault key ID should match created key"
  }

  assert {
    condition     = module.databricks.resource.managed_disk_cmk_rotation_to_latest_version_enabled == true
    error_message = "Managed disk CMK rotation should be enabled"
  }

  assert {
    condition     = azurerm_key_vault_key.dbfs_root.key_type == "RSA"
    error_message = "DBFS root key should be RSA type"
  }

  assert {
    condition     = azurerm_key_vault_key.cmkms.key_type == "RSA"
    error_message = "Managed services key should be RSA type"
  }

  assert {
    condition     = azurerm_key_vault_key.managed_disk_cmk.key_type == "RSA"
    error_message = "Managed disk key should be RSA type"
  }
}

run "customer_managed_key_example_apply" {
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
    condition     = module.databricks.databricks_workspace_managed_disk_identity != null
    error_message = "Managed disk identity should be created after apply"
  }

  assert {
    condition     = module.databricks.databricks_workspace_storage_account_identity != null
    error_message = "Storage account identity should be created after apply"
  }
}