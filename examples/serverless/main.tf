terraform {
  required_version = ">= 1.6, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.117, < 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
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

# An Access Connector with a system-assigned managed identity is required for Unity Catalog.
resource "azurerm_databricks_access_connector" "this" {
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.databricks_workspace.name_unique}-access-connector"
  resource_group_name = azurerm_resource_group.this.name

  identity {
    type = "SystemAssigned"
  }
}

# Deploy a Databricks workspace with Unity Catalog enabled for Serverless SQL and Serverless Compute.
module "databricks" {
  source = "../.."

  location            = "uk south"
  name                = module.naming.databricks_workspace.name_unique
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "premium"
  access_connector_id = azurerm_databricks_access_connector.this.id
  enable_telemetry    = var.enable_telemetry

  # Enable Unity Catalog as the default catalog, which is required for Serverless SQL and Serverless Compute.
  default_catalog = {
    initial_type = "UnityCatalog"
  }
}
