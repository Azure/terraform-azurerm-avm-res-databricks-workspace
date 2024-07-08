<!-- BEGIN_TF_DOCS -->
# VNet injection example

The default deployment of Azure Databricks is a fully managed service on Azure: all compute plane resources, including a VNet that all clusters will be associated with, are deployed to a locked resource group. If you require network customization, however, you can deploy Azure Databricks compute plane resources in your own virtual network (sometimes called VNet injection), enabling you to:

- Connect Azure Databricks to other Azure services (such as Azure Storage) in a more secure manner using service endpoints or private endpoints.
- Connect to on-premises data sources for use with Azure Databricks, taking advantage of user-defined routes.
- Connect Azure Databricks to a network virtual appliance to inspect all outbound traffic and take actions according to allow and deny rules, by using user-defined routes.
- Configure Azure Databricks to use custom DNS.
- Configure network security group (NSG) rules to specify egress traffic restrictions.
- Deploy Azure Databricks clusters in your existing VNet.

```hcl
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
# tflint-ignore: terraform_unused_declarations
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

# A vnet is required for vnet injection.
resource "azurerm_virtual_network" "this" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
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
  address_prefixes                          = ["10.0.3.0/24"]
  name                                      = "${module.naming.subnet.name_unique}-private-endpoint"
  resource_group_name                       = azurerm_resource_group.this.name
  virtual_network_name                      = azurerm_virtual_network.this.name
  private_endpoint_network_policies_enabled = false
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

  security_rule {
    access                     = "Allow"
    description                = "Required for worker nodes communication within a cluster."
    destination_address_prefix = "VirtualNetwork"
    destination_port_range     = "*"
    direction                  = "Inbound"
    name                       = "Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-worker-inbound"
    priority                   = 100
    protocol                   = "*"
    source_address_prefix      = "VirtualNetwork"
    source_port_range          = "*"
  }
  security_rule {
    access                     = "Allow"
    description                = "Required for workers communication with Databricks Webapp."
    destination_address_prefix = "AzureDatabricks"
    destination_port_range     = "443"
    direction                  = "Outbound"
    name                       = "Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-databricks-webapp"
    priority                   = 100
    protocol                   = "Tcp"
    source_address_prefix      = "VirtualNetwork"
    source_port_range          = "*"
  }
  security_rule {
    access                     = "Allow"
    description                = "Required for workers communication with Azure SQL services."
    destination_address_prefix = "Sql"
    destination_port_range     = "3306"
    direction                  = "Outbound"
    name                       = "Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-sql"
    priority                   = 101
    protocol                   = "Tcp"
    source_address_prefix      = "VirtualNetwork"
    source_port_range          = "*"
  }
  security_rule {
    access                     = "Allow"
    description                = "Required for workers communication with Azure Storage services."
    destination_address_prefix = "Storage"
    destination_port_range     = "443"
    direction                  = "Outbound"
    name                       = "Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-storage"
    priority                   = 102
    protocol                   = "Tcp"
    source_address_prefix      = "VirtualNetwork"
    source_port_range          = "*"
  }
  security_rule {
    access                     = "Allow"
    description                = "Required for worker nodes communication within a cluster."
    destination_address_prefix = "VirtualNetwork"
    destination_port_range     = "*"
    direction                  = "Outbound"
    name                       = "Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-worker-outbound"
    priority                   = 103
    protocol                   = "*"
    source_address_prefix      = "VirtualNetwork"
    source_port_range          = "*"
  }
  security_rule {
    access                     = "Allow"
    description                = "Required for worker communication with Azure Eventhub services."
    destination_address_prefix = "EventHub"
    destination_port_range     = "9093"
    direction                  = "Outbound"
    name                       = "Microsoft.Databricks-workspaces_UseOnly_databricks-worker-to-eventhub"
    priority                   = 104
    protocol                   = "Tcp"
    source_address_prefix      = "VirtualNetwork"
    source_port_range          = "*"
  }
}

# A private DNS zone for the private endpoint.
resource "azurerm_private_dns_zone" "azuredatabricks" {
  name                = "privatelink.azuredatabricks.net"
  resource_group_name = azurerm_resource_group.this.name
}

# Create DataBricks workspace with vnet injection and private endpoint.
module "databricks" {
  source = "../.."

  location            = module.regions.regions[random_integer.region_index.result].name
  name                = module.naming.databricks_workspace.name_unique
  resource_group_name = azurerm_resource_group.this.name

  sku                           = "premium"
  public_network_access_enabled = true
  custom_parameters = {
    no_public_ip                                         = true
    public_subnet_name                                   = azurerm_subnet.public.name
    public_subnet_network_security_group_association_id  = azurerm_subnet_network_security_group_association.public.id
    private_subnet_name                                  = azurerm_subnet.private.name
    private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.private.id
    virtual_network_id                                   = azurerm_virtual_network.this.id
  }

  private_endpoints = {
    databricks_ui_api = {
      subresource_name              = "databricks_ui_api"
      location                      = azurerm_resource_group.this.location
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.azuredatabricks.id]
      subnet_resource_id            = azurerm_subnet.privateendpoint.id
    }
  }
}



```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.0.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (>= 3.7.0, < 4.0.0)

- <a name="requirement_random"></a> [random](#requirement\_random) (>= 3.5.0, < 4.0.0)

## Providers

The following providers are used by this module:

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (>= 3.7.0, < 4.0.0)

- <a name="provider_random"></a> [random](#provider\_random) (>= 3.5.0, < 4.0.0)

## Resources

The following resources are used by this module:

- [azurerm_network_security_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) (resource)
- [azurerm_private_dns_zone.azuredatabricks](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) (resource)
- [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.private](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet.privateendpoint](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet.public](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet_network_security_group_association.private](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) (resource)
- [azurerm_subnet_network_security_group_association.public](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) (resource)
- [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [random_integer.region_index](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) (resource)
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