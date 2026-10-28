mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "azurerm" {
  mock_data "azurerm_resource_group" {
    defaults = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-unit"
      location = "eastus"
    }
  }
}

mock_provider "random" {}

run "managed_dns_group_unknown_role_name" {
  command = plan

  module {
    source = "./tests/unit/fixtures/unknown_role_name"
  }

  variables {
    manage_dns_zone_group = true
  }

  assert {
    condition     = toset(keys(output.private_endpoints)) == toset(["ui"])
    error_message = "The managed endpoint must remain plannable with an apply-time role assignment name."
  }
}

run "unmanaged_dns_group_unknown_role_name" {
  command = plan

  module {
    source = "./tests/unit/fixtures/unknown_role_name"
  }

  variables {
    manage_dns_zone_group = false
  }

  assert {
    condition     = toset(keys(output.private_endpoints)) == toset(["ui"])
    error_message = "The unmanaged endpoint must remain plannable with an apply-time role assignment name."
  }
}
