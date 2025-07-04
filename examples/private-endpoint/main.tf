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

# We need the tenant id.
# tflint-ignore: terraform_unused_declarations
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

# A vnet is required for vnet injection.
resource "azurerm_virtual_network" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.0.0/16"]
}
# A host (public) subnet is required for vnet injection.
resource "azurerm_subnet" "public" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = "${module.naming.subnet.name_unique}-public"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name

  delegation {
    name = "databricks-del-public"

    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

# A container (private) subnet is required for vnet injection.
resource "azurerm_subnet" "private" {
  address_prefixes     = ["10.0.2.0/24"]
  name                 = "${module.naming.subnet.name_unique}-private"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name

  delegation {
    name = "databricks-del-private"

    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

# A private endpoint vnet
resource "azurerm_subnet" "privateendpoint" {
  address_prefixes     = ["10.0.3.0/24"]
  name                 = "${module.naming.subnet.name_unique}-private-endpoint"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
}

# A network security group association is required for vnet injection.
resource "azurerm_subnet_network_security_group_association" "private" {
  network_security_group_id = azurerm_network_security_group.this.id
  subnet_id                 = azurerm_subnet.private.id
}

resource "azurerm_subnet_network_security_group_association" "public" {
  network_security_group_id = azurerm_network_security_group.this.id
  subnet_id                 = azurerm_subnet.public.id
}

# A network security group is required for vnet injection.
resource "azurerm_network_security_group" "this" {
  location            = azurerm_resource_group.this.location
  name                = "databricks-nsg"
  resource_group_name = azurerm_resource_group.this.name
}

# A private DNS zone for the private endpoint.
resource "azurerm_private_dns_zone" "azuredatabricks" {
  name                = "privatelink.azuredatabricks.net"
  resource_group_name = azurerm_resource_group.this.name
}

# create access connector for Databricks workspace
resource "azurerm_databricks_access_connector" "this" {
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.databricks_workspace.name_unique}-access-connector"
  resource_group_name = azurerm_resource_group.this.name

  identity {
    type = "SystemAssigned"
  }
}

# Create DataBricks workspace with vnet injection and private endpoint.
module "databricks" {
  source = "../.."

  location            = "uk south"
  name                = module.naming.databricks_workspace.name_unique
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "premium"
  access_connector_id = azurerm_databricks_access_connector.this.id
  custom_parameters = {
    no_public_ip                                         = true
    public_subnet_name                                   = azurerm_subnet.public.name
    public_subnet_network_security_group_association_id  = azurerm_subnet_network_security_group_association.public.id
    private_subnet_name                                  = azurerm_subnet.private.name
    private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.private.id
    virtual_network_id                                   = azurerm_virtual_network.this.id
  }
  default_storage_firewall_enabled      = true
  network_security_group_rules_required = "NoAzureDatabricksRules" # "AllRules", Required when public_network_access_enabled is set to false.
  private_endpoints = {
    databricks_ui_api = {
      name                            = "${module.naming.private_endpoint.name_unique}-databricks-ui-api"
      private_service_connection_name = "${module.naming.private_endpoint.name_unique}-pse-databricks-ui-api"
      subresource_name                = "databricks_ui_api"
      location                        = azurerm_resource_group.this.location
      private_dns_zone_resource_ids   = [azurerm_private_dns_zone.azuredatabricks.id]
      subnet_resource_id              = azurerm_subnet.privateendpoint.id
    }
    # browser_authentication = {
    #   name                            = "${module.naming.private_endpoint.name_unique}-browser-authentication"
    #   private_service_connection_name = "${module.naming.private_endpoint.name_unique}-pse-browser-authentication"
    #   subresource_name                = "browser_authentication"
    #   location                        = azurerm_resource_group.this.location
    #   private_dns_zone_resource_ids   = [azurerm_private_dns_zone.azuredatabricks.id]
    #   subnet_resource_id              = azurerm_subnet.privateendpoint.id
    # }
  }
  public_network_access_enabled = true
}
