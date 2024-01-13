terraform {
  required_version = ">= 1.0.0"
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

# We need the tenant id.
data "azurerm_client_config" "this" {}

# This allows us to randomize the region for the resource group.
module "regions" {
  # checkov:skip=CKV_TF_1
  source  = "Azure/regions/azurerm"
  version = ">= 0.3.0"
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  min = 0
  max = length(module.regions.regions) - 1
}

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  # checkov:skip=CKV_TF_1
  source  = "Azure/naming/azurerm"
  version = "0.3.0"
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  name     = module.naming.resource_group.name_unique
  location = module.regions.regions[random_integer.region_index.result].name
}

#Key Vault needed for CMK
resource "azurerm_key_vault" "this" {
  # checkov:skip=CKV_AZURE_109: This is a test resource
  # checkov:skip=CKV_AZURE_189: This is a test resource
  name                       = module.naming.key_vault.name_unique
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  tenant_id                  = data.azurerm_client_config.this.tenant_id
  enable_rbac_authorization  = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
  sku_name                   = "standard"

}

# Create keys for CMK
resource "azurerm_key_vault_key" "cmkms" {
  name         = "${module.naming.key_vault_key.name_unique}-cmkms"
  key_vault_id = azurerm_key_vault.this.id
  # checkov:skip=CKV_AZURE_112
  # checkov:skip=CKV_AZURE_40
  key_type = "RSA"
  key_size = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }

    expire_after         = "P90D"
    notify_before_expiry = "P29D"
  }
  depends_on = [azurerm_role_assignment.current_user]
}


resource "azurerm_key_vault_key" "managed_disk_cmk" {
  name         = "${module.naming.key_vault_key.name_unique}-cmkds"
  key_vault_id = azurerm_key_vault.this.id
  # checkov:skip=CKV_AZURE_112
  # checkov:skip=CKV_AZURE_40
  key_type = "RSA"
  key_size = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }

    expire_after         = "P90D"
    notify_before_expiry = "P29D"
  }
  depends_on = [azurerm_role_assignment.current_user]
}

# create a key vault key for the DBFS encryption
resource "azurerm_key_vault_key" "dbfs_root" {
  name         = "${module.naming.key_vault_key.name_unique}-dbfs-root"
  key_vault_id = azurerm_key_vault.this.id
  # checkov:skip=CKV_AZURE_112
  # checkov:skip=CKV_AZURE_40
  key_type = "RSA"
  key_size = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }

    expire_after         = "P90D"
    notify_before_expiry = "P29D"
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
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto User"
  principal_id         = data.azuread_service_principal.this.object_id
}


# Add the current user to the key vault access policy
resource "azurerm_role_assignment" "current_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.this.object_id
}

module "databricks" {
  source = "../.."

  name                                                = module.naming.databricks_workspace.name_unique
  resource_group_name                                 = azurerm_resource_group.this.name
  location                                            = azurerm_resource_group.this.location
  sku                                                 = "premium"
  managed_services_cmk_key_vault_key_id               = azurerm_key_vault_key.cmkms.id
  managed_disk_cmk_key_vault_key_id                   = azurerm_key_vault_key.managed_disk_cmk.id
  managed_disk_cmk_rotation_to_latest_version_enabled = true
  customer_managed_key_enabled                        = true
  dbfs_root_cmk_key_vault_key_id                      = azurerm_key_vault_key.dbfs_root.id
}

# add the disk encryption key to the key vault access policy
resource "azurerm_role_assignment" "disk_encryption_set" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto User"
  principal_id         = module.databricks.databricks_workspace_managed_disk_identity.principal_id
}

# add the storage account encryption key to the key vault access policy
resource "azurerm_role_assignment" "storage_account" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto User"
  principal_id         = module.databricks.databricks_workspace_storage_account_identity.principal_id
}
