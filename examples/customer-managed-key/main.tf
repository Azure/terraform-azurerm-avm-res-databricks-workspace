terraform {
  required_version = ">= 1.6, < 2.0"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.15.0"
    }
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

# We need the tenant id.
data "azurerm_client_config" "this" {}

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

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  # checkov:skip=CKV_TF_1
  source  = "Azure/naming/azurerm"
  version = "0.4.1"
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = "uk south"
  name     = module.naming.resource_group.name_unique
}

#Key Vault needed for CMK
resource "azurerm_key_vault" "this" {
  location = azurerm_resource_group.this.location
  # checkov:skip=CKV_AZURE_109: This is a test resource
  # checkov:skip=CKV_AZURE_189: This is a test resource
  name                       = module.naming.key_vault.name_unique
  resource_group_name        = azurerm_resource_group.this.name
  sku_name                   = "standard"
  tenant_id                  = data.azurerm_client_config.this.tenant_id
  enable_rbac_authorization  = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 7
}

# Create keys for CMK
resource "azurerm_key_vault_key" "cmkms" {
  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
  # checkov:skip=CKV_AZURE_112
  # checkov:skip=CKV_AZURE_40
  key_type     = "RSA"
  key_vault_id = azurerm_key_vault.this.id
  name         = "${module.naming.key_vault_key.name_unique}-cmkms"
  key_size     = 2048

  rotation_policy {
    expire_after         = "P90D"
    notify_before_expiry = "P29D"

    automatic {
      time_before_expiry = "P30D"
    }
  }

  depends_on = [azurerm_role_assignment.current_user]
}


resource "azurerm_key_vault_key" "managed_disk_cmk" {
  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
  # checkov:skip=CKV_AZURE_112
  # checkov:skip=CKV_AZURE_40
  key_type     = "RSA"
  key_vault_id = azurerm_key_vault.this.id
  name         = "${module.naming.key_vault_key.name_unique}-cmkds"
  key_size     = 2048

  rotation_policy {
    expire_after         = "P90D"
    notify_before_expiry = "P29D"

    automatic {
      time_before_expiry = "P30D"
    }
  }

  depends_on = [azurerm_role_assignment.current_user]
}

# create a key vault key for the DBFS encryption
resource "azurerm_key_vault_key" "dbfs_root" {
  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
  # checkov:skip=CKV_AZURE_112
  # checkov:skip=CKV_AZURE_40
  key_type     = "RSA"
  key_vault_id = azurerm_key_vault.this.id
  name         = "${module.naming.key_vault_key.name_unique}-dbfs-root"
  key_size     = 2048

  rotation_policy {
    expire_after         = "P90D"
    notify_before_expiry = "P29D"

    automatic {
      time_before_expiry = "P30D"
    }
  }

  depends_on = [azurerm_role_assignment.current_user, azurerm_role_assignment.storage_account, azurerm_role_assignment.azuredatabricks]
}
# Get the application IDs for APIs published by Microsoft
data "azuread_application_published_app_ids" "well_known" {}
# Get the object id of the Azure DataBricks service principal
data "azuread_service_principal" "this" {
  client_id = data.azuread_application_published_app_ids.well_known.result["AzureDataBricks"]
}

# Add the Azure DataBricks service principal to the key vault access policy
resource "azurerm_role_assignment" "azuredatabricks" {
  principal_id         = data.azuread_service_principal.this.object_id
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto User"
}


# Add the current user to the key vault access policy
resource "azurerm_role_assignment" "current_user" {
  principal_id         = data.azurerm_client_config.this.object_id
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto Officer"
}

module "databricks" {
  source = "../.."

  location                                            = "uk south"
  name                                                = module.naming.databricks_workspace.name_unique
  resource_group_name                                 = azurerm_resource_group.this.name
  sku                                                 = "premium"
  customer_managed_key_enabled                        = true
  dbfs_root_cmk_key_vault_key_id                      = azurerm_key_vault_key.dbfs_root.id
  managed_disk_cmk_key_vault_key_id                   = azurerm_key_vault_key.managed_disk_cmk.id
  managed_disk_cmk_rotation_to_latest_version_enabled = true
  managed_services_cmk_key_vault_key_id               = azurerm_key_vault_key.cmkms.id
}

# add the disk encryption key to the key vault access policy
resource "azurerm_role_assignment" "disk_encryption_set" {
  principal_id         = module.databricks.databricks_workspace_managed_disk_identity.principal_id
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto User"
}

# add the storage account encryption key to the key vault access policy
resource "azurerm_role_assignment" "storage_account" {
  principal_id         = module.databricks.databricks_workspace_storage_account_identity.principal_id
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto User"
}
