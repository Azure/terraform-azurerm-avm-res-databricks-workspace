mock_provider "azapi" {
  mock_resource "azapi_resource_action" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Databricks/workspaces/test"
    }
  }

  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000000"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
      tenant_id                = "00000000-0000-0000-0000-000000000001"
    }
  }
}

mock_provider "azurerm" {
  mock_resource "azurerm_databricks_workspace" {
    defaults = {
      id                        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Databricks/workspaces/test"
      workspace_id              = "1234567890"
      workspace_url             = "adb-1234567890.1.azuredatabricks.net"
      managed_resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-managed"
    }
  }

  mock_data "azurerm_resource_group" {
    defaults = {
      location = "westus"
    }
  }
}

mock_provider "modtm" {}

mock_provider "random" {}

variables {
  name                = "test"
  resource_group_name = "test-rg"
  location            = "westus"
  sku                 = "premium"
}

run "default_catalog_not_created_when_null" {
  command = apply

  variables {
    default_catalog = null
  }

  assert {
    condition     = length(azapi_resource_action.default_catalog) == 0
    error_message = "azapi_resource_action.default_catalog should not be created when default_catalog is null"
  }
}

run "default_catalog_created_with_unity_catalog" {
  command = apply

  variables {
    default_catalog = {
      initial_type = "UnityCatalog"
      initial_name = null
    }
  }

  assert {
    condition     = length(azapi_resource_action.default_catalog) == 1
    error_message = "azapi_resource_action.default_catalog should be created when default_catalog is set"
  }

  assert {
    condition     = azapi_resource_action.default_catalog[0].body.properties.defaultCatalog.initialType == "UnityCatalog"
    error_message = "defaultCatalog initialType should be UnityCatalog"
  }
}

run "default_catalog_created_with_hive_metastore" {
  command = apply

  variables {
    default_catalog = {
      initial_type = "HiveMetastore"
      initial_name = null
    }
  }

  assert {
    condition     = length(azapi_resource_action.default_catalog) == 1
    error_message = "azapi_resource_action.default_catalog should be created when default_catalog is set"
  }

  assert {
    condition     = azapi_resource_action.default_catalog[0].body.properties.defaultCatalog.initialType == "HiveMetastore"
    error_message = "defaultCatalog initialType should be HiveMetastore"
  }
}

run "default_catalog_created_with_initial_name" {
  command = apply

  variables {
    default_catalog = {
      initial_type = "UnityCatalog"
      initial_name = "my-catalog"
    }
  }

  assert {
    condition     = length(azapi_resource_action.default_catalog) == 1
    error_message = "azapi_resource_action.default_catalog should be created when default_catalog is set"
  }

  assert {
    condition     = azapi_resource_action.default_catalog[0].body.properties.defaultCatalog.initialName == "my-catalog"
    error_message = "defaultCatalog initialName should be my-catalog"
  }
}

run "default_catalog_invalid_initial_type" {
  command = plan

  variables {
    default_catalog = {
      initial_type = "InvalidType"
      initial_name = null
    }
  }

  expect_failures = [
    var.default_catalog,
  ]
}

run "access_connector_without_storage_firewall_sets_false_explicitly" {
  command = plan

  variables {
    access_connector_id              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Databricks/accessConnectors/test"
    default_storage_firewall_enabled = false
  }

  assert {
    condition     = azurerm_databricks_workspace.this.access_connector_id == var.access_connector_id
    error_message = "Databricks Workspace access_connector_id did not match expected"
  }

  assert {
    condition     = azurerm_databricks_workspace.this.default_storage_firewall_enabled == false
    error_message = "Databricks Workspace default_storage_firewall_enabled should be explicitly false when access_connector_id is set"
  }
}
