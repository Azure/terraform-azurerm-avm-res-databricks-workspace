<!-- BEGIN_TF_DOCS -->
# Customer Managed Keys example

This example shows how to deploy the databricks module with customer managed keys for the following:

- Customer-managed keys for DBFS root.
- Customer-managed keys for managed services.
- Customer-managed keys for Azure managed disks.

```hcl
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.15.0"
    }
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
  max = length(module.regions.regions) - 1
  min = 0
}

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  # checkov:skip=CKV_TF_1
  source  = "Azure/naming/azurerm"
  version = "0.3.0"
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = module.regions.regions[random_integer.region_index.result].name
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

  name                = module.naming.databricks_workspace.name_unique
  resource_group_name = azurerm_resource_group.this.name

  sku                                                 = "premium"
  managed_services_cmk_key_vault_key_id               = azurerm_key_vault_key.cmkms.id
  managed_disk_cmk_key_vault_key_id                   = azurerm_key_vault_key.managed_disk_cmk.id
  managed_disk_cmk_rotation_to_latest_version_enabled = true
  customer_managed_key_enabled                        = true
  dbfs_root_cmk_key_vault_key_id                      = azurerm_key_vault_key.dbfs_root.id
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
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.0.0)

- <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) (>= 2.15.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (>= 3.7.0, < 4.0.0)

- <a name="requirement_random"></a> [random](#requirement\_random) (>= 3.5.0, < 4.0.0)

## Providers

The following providers are used by this module:

- <a name="provider_azuread"></a> [azuread](#provider\_azuread) (>= 2.15.0)

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (>= 3.7.0, < 4.0.0)

- <a name="provider_random"></a> [random](#provider\_random) (>= 3.5.0, < 4.0.0)

## Resources

The following resources are used by this module:

- [azurerm_key_vault.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) (resource)
- [azurerm_key_vault_key.cmkms](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_key) (resource)
- [azurerm_key_vault_key.dbfs_root](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_key) (resource)
- [azurerm_key_vault_key.managed_disk_cmk](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_key) (resource)
- [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_role_assignment.azuredatabricks](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [azurerm_role_assignment.current_user](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [azurerm_role_assignment.disk_encryption_set](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [azurerm_role_assignment.storage_account](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [random_integer.region_index](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) (resource)
- [azuread_application_published_app_ids.well_known](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/application_published_app_ids) (data source)
- [azuread_service_principal.this](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/service_principal) (data source)
- [azurerm_client_config.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

No required inputs.

## Optional Inputs

No optional inputs.

## Outputs

No outputs.

## Modules

The following Modules are called:

### <a name="module_databricks"></a> [databricks](#module\_databricks)

Source: ../..

Version:

### <a name="module_naming"></a> [naming](#module\_naming)

Source: Azure/naming/azurerm

Version: 0.3.0

### <a name="module_regions"></a> [regions](#module\_regions)

Source: Azure/regions/azurerm

Version: >= 0.3.0

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft.
Microsoft may use this information to provide services and improve our products and services.
You may turn off the telemetry as described in the repository.
There are also some features in the software that may enable you and Microsoft to collect data from users of your applications.
If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement.
Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>.
You can learn more about data collection and use in the help documentation and our privacy statement.
Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->