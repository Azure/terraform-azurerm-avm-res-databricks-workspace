mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}

variables {
  name                = "test"
  resource_group_name = "test-rg"
  location            = "westus"
  sku                 = "premium"
}

# default_storage_firewall_enabled requires either access_connector_id or
# access_connector_key (issue #148).
run "firewall_requires_access_connector" {
  command = plan

  variables {
    default_storage_firewall_enabled = true
  }

  expect_failures = [
    var.access_connector_id,
  ]
}

# access_connector_key must reference a key that exists in the access_connector map.
run "invalid_access_connector_key" {
  command = plan

  variables {
    access_connector_key = "does-not-exist"
  }

  expect_failures = [
    var.access_connector_key,
  ]
}

# access_connector_id and access_connector_key are mutually exclusive.
run "mutually_exclusive_access_connector" {
  command = plan

  variables {
    access_connector_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Databricks/accessConnectors/ac"
    access_connector = {
      primary = {
        name     = "primary-access-connector"
        identity = { type = "SystemAssigned" }
      }
    }
    access_connector_key = "primary"
  }

  expect_failures = [
    var.access_connector_id,
  ]
}

# When access_connector_key references a module-created connector, its ID is
# wired into the workspace body (issue #148).
run "access_connector_key_wires_created_connector" {
  command = apply

  override_data {
    target = data.azurerm_resource_group.parent
    values = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg"
      location = "westus"
    }
  }

  variables {
    default_storage_firewall_enabled = true
    access_connector = {
      primary = {
        name     = "primary-access-connector"
        identity = { type = "SystemAssigned" }
      }
    }
    access_connector_key = "primary"
  }

  assert {
    condition     = azapi_resource.this.body.properties.accessConnector.id == azurerm_databricks_access_connector.this["primary"].id
    error_message = "Workspace accessConnector.id did not match the module-created access connector ID"
  }

  assert {
    condition     = azapi_resource.this.body.properties.defaultStorageFirewall == "Enabled"
    error_message = "defaultStorageFirewall was not enabled"
  }
}
