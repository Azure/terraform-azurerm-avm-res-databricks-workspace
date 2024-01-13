provider "azurerm" {
  features {}
}

variables {
  name                = "test"
  resource_group_name = "test-rg"
  location            = "westus"
  sku                 = "standard"
  lock = {
    name = "test-lock"
    kind = "ReadOnly"
  }
}

run "uses_root_level_value" {
  command = plan

  assert {
    condition     = azurerm_databricks_workspace.this.name == var.name
    error_message = "Databricks Workspace name did not match expected"
  }

  assert {
    condition     = azurerm_databricks_workspace.this.resource_group_name == var.resource_group_name
    error_message = "Databricks Workspace resource group name did not match expected"
  }

  assert {
    condition     = azurerm_databricks_workspace.this.location == var.location
    error_message = "Databricks Workspace location did not match expected"
  }

  assert {
    condition     = azurerm_databricks_workspace.this.sku == var.sku
    error_message = "Databricks Workspace SKU did not match expected"
  }

  assert {
    condition     = azurerm_management_lock.this[0].name == var.lock.name
    error_message = "Databricks Workspace lock did not match expected"
  }

  assert {
    condition     = azurerm_management_lock.this[0].lock_level == var.lock.kind
    error_message = "Databricks Workspace lock did not match expected"
  }
}

run "overrides_root_level_value" {
  command = plan

  variables {
    name                = "other"
    resource_group_name = "other-rg"
    location            = "eastus"
    sku                 = "premium"
  }

  assert {
    condition     = azurerm_databricks_workspace.this.name == var.name
    error_message = "Databricks Workspace name did not match expected"
  }

  assert {
    condition     = azurerm_databricks_workspace.this.resource_group_name == var.resource_group_name
    error_message = "Databricks Workspace resource group name did not match expected"
  }

  assert {
    condition     = azurerm_databricks_workspace.this.location == var.location
    error_message = "Databricks Workspace location did not match expected"
  }

  assert {
    condition     = azurerm_databricks_workspace.this.sku == var.sku
    error_message = "Databricks Workspace SKU did not match expected"
  }
}

run "invalid_input" {
  command = plan

  variables {
    name = "invalid=p"
    sku  = "PremiumPlus"
    lock = {
      name = null
      kind = "Invalid"
    }
  }

  expect_failures = [
    var.name,
    var.sku,
    var.lock.kind,
  ]
}