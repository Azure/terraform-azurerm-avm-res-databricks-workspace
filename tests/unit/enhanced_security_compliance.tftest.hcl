mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      client_id                = "00000000-0000-0000-0000-000000000001"
      object_id                = "00000000-0000-0000-0000-000000000002"
      subscription_id          = "00000000-0000-0000-0000-000000000003"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000003"
      tenant_id                = "00000000-0000-0000-0000-000000000004"
    }
  }

  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-unit/providers/Microsoft.Databricks/workspaces/unit-databricks"
    }
  }

  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        value = [{
          id = "/subscriptions/00000000-0000-0000-0000-000000000003/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        }]
      }
    }
  }
}

mock_provider "azurerm" {
  mock_data "azurerm_resource_group" {
    defaults = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-unit"
      location = "westus"
    }
  }
}

mock_provider "random" {
  mock_resource "random_uuid" {
    defaults = {
      result = "00000000-0000-0000-0000-000000000005"
    }
  }
}

mock_provider "terraform" {
  mock_resource "terraform_data" {
    defaults = {
      id = "00000000-0000-0000-0000-000000000006"
    }
  }
}

variables {
  location            = "eastus"
  name                = "unit-databricks"
  resource_group_name = "rg-unit"
  sku                 = "premium"
}

run "omitted_compliance_is_null" {
  command = apply

  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }

  assert {
    condition     = var.enhanced_security_compliance == null
    error_message = "Omitting enhanced_security_compliance must preserve its null default."
  }
}

run "explicit_null_compliance_is_valid" {
  command = apply

  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }

  variables {
    enhanced_security_compliance = null
  }

  assert {
    condition     = var.enhanced_security_compliance == null
    error_message = "An explicitly null enhanced_security_compliance value must be accepted."
  }
}

run "valid_enabled_compliance_is_applied" {
  command = apply

  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }

  variables {
    enhanced_security_compliance = {
      automatic_cluster_update_enabled      = true
      compliance_security_profile_enabled   = true
      compliance_security_profile_standards = ["HIPAA"]
      enhanced_security_monitoring_enabled  = true
    }
  }

  assert {
    condition = (
      azapi_resource.this.body.properties.enhancedSecurityCompliance.complianceSecurityProfile.value == "Enabled" &&
      length(azapi_resource.this.body.properties.enhancedSecurityCompliance.complianceSecurityProfile.complianceStandards) == 1 &&
      azapi_resource.this.body.properties.enhancedSecurityCompliance.complianceSecurityProfile.complianceStandards[0] == "HIPAA"
    )
    error_message = "A valid enabled compliance object must be passed to the workspace resource."
  }
}

run "missing_prerequisites_are_rejected" {
  command = plan

  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }

  variables {
    enhanced_security_compliance = {
      compliance_security_profile_enabled  = true
      enhanced_security_monitoring_enabled = true
    }
  }

  expect_failures = [var.enhanced_security_compliance]
}

run "standards_without_profile_are_rejected" {
  command = plan

  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }

  variables {
    enhanced_security_compliance = {
      compliance_security_profile_standards = ["HIPAA"]
    }
  }

  expect_failures = [var.enhanced_security_compliance]
}

run "unknown_standard_is_rejected" {
  command = plan

  providers = {
    azapi     = azapi
    azurerm   = azurerm
    random    = random
    terraform = terraform
  }

  variables {
    enhanced_security_compliance = {
      automatic_cluster_update_enabled      = true
      compliance_security_profile_enabled   = true
      compliance_security_profile_standards = ["NOT_A_STANDARD"]
      enhanced_security_monitoring_enabled  = true
    }
  }

  expect_failures = [var.enhanced_security_compliance]
}
