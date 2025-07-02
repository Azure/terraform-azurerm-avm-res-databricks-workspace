terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.7.0, < 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0, < 4.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}


## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
module "regions" {
  # checkov:skip=CKV_TF_1
  source  = "Azure/regions/azurerm"
  version = ">= 0.8.0"
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}
## End of section to provide a random Azure region for the resource group

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  # checkov:skip=CKV_TF_1
  source  = "Azure/naming/azurerm"
  version = ">= 0.4.1"
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = "uk south"
  name     = module.naming.resource_group.name_unique
}

# Create a Log Analytics Workspace for the diagnostic settings
resource "azurerm_log_analytics_workspace" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.log_analytics_workspace.name_unique
  resource_group_name = azurerm_resource_group.this.name
  retention_in_days   = 30
  sku                 = "PerGB2018"
}

module "databricks" {
  source = "../.."

  location            = "uk south"
  name                = module.naming.databricks_workspace.name_unique
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "premium"
  # Diagnostic settings are only available for premium workspaces
  diagnostic_settings = {
    databricks = {
      name                  = "diag-${module.naming.databricks_workspace.name_unique}"
      workspace_resource_id = azurerm_log_analytics_workspace.this.id
    }
  }
  enable_telemetry = var.enable_telemetry
}
