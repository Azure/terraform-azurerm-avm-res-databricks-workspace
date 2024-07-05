<!-- BEGIN_TF_DOCS -->
# terraform-azurerm-res-databricks-workspace

Manages a Databricks Workspace

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.6.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (>= 3.71.0)

- <a name="requirement_random"></a> [random](#requirement\_random) (>= 3.5.0)

## Providers

The following providers are used by this module:

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (>= 3.71.0)

- <a name="provider_random"></a> [random](#provider\_random) (>= 3.5.0)

## Resources

The following resources are used by this module:

- [azurerm_databricks_access_connector.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/databricks_access_connector) (resource)
- [azurerm_databricks_virtual_network_peering.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/databricks_virtual_network_peering) (resource)
- [azurerm_databricks_workspace.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/databricks_workspace) (resource)
- [azurerm_databricks_workspace_root_dbfs_customer_managed_key.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/databricks_workspace_root_dbfs_customer_managed_key) (resource)
- [azurerm_management_lock.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) (resource)
- [azurerm_monitor_diagnostic_setting.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) (resource)
- [azurerm_private_endpoint.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) (resource)
- [azurerm_private_endpoint_application_security_group_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint_application_security_group_association) (resource)
- [azurerm_resource_group_template_deployment.telemetry](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group_template_deployment) (resource)
- [azurerm_role_assignment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [random_id.telem](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) (resource)
- [azurerm_resource_group.parent](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_location"></a> [location](#input\_location)

Description: Azure region where the resource should be deployed.

Type: `string`

### <a name="input_name"></a> [name](#input\_name)

Description: Specifies the name of the Databricks Workspace resource. Changing this forces a new resource to be created.

Type: `string`

### <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name)

Description: The name of the Resource Group in which the Databricks Workspace should exist. Changing this forces a new resource to be created.

Type: `string`

### <a name="input_sku"></a> [sku](#input\_sku)

Description:   The 'sku' value must be one of 'standard', 'premium', or 'trial'.  
  NOTE: Downgrading to a trial sku from a standard or premium sku will force a new resource to be created.

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_access_connector"></a> [access\_connector](#input\_access\_connector)

Description:   
Configuration options for the Databricks Access Connector resource. This map includes the following attributes:

- `name` (Required): Specifies the name of the Databricks Access Connector resource. Changing this forces a new resource to be created.
- `resource_group_name` (Optional): The name of the Resource Group in which the Databricks Access Connector should exist. Defaults to the resource group of the databricks instance.
- `location` (Optional): Specifies the supported Azure location where the resource has to be created. Defaults to the location of the databricks instance.
- `identity` (Optional): An identity block. This block supports the following:
  - `type` (Required): Specifies the type of Managed Service Identity that should be configured on the Databricks Access Connector. Possible values include SystemAssigned or UserAssigned.
  - `identity_ids` (Optional): Specifies a list of User Assigned Managed Identity IDs to be assigned to the Databricks Access Connector. Only one User Assigned Managed Identity ID is supported per Databricks Access Connector resource. Note: identity\_ids are required when type is set to UserAssigned.
- `tags` (Optional): A mapping of tags to assign to the resource.

Type:

```hcl
map(object({
    name                = string
    resource_group_name = optional(string, null)
    location            = optional(string, null)
    identity = optional(object({
      type         = string
      identity_ids = optional(list(string))
    }))
    tags = optional(map(string))
  }))
```

Default: `{}`

### <a name="input_custom_parameters"></a> [custom\_parameters](#input\_custom\_parameters)

Description: A map of custom parameters for configuring the Databricks Workspace. This object allows for detailed configuration, with each attribute representing a specific setting:

- `machine_learning_workspace_id` - (Optional) The ID of an Azure Machine Learning workspace to link with the Databricks workspace.
- `nat_gateway_name` - (Optional) Name of the NAT gateway for Secure Cluster Connectivity (No Public IP) workspace subnets. Defaults to 'nat-gateway'.
- `public_ip_name` - (Optional) Name of the Public IP for No Public IP workspace with managed vNet. Defaults to 'nat-gw-public-ip'.
- `no_public_ip` - (Optional) Specifies whether public IP Addresses are not allowed. Defaults to false. Note: Updating this parameter is only allowed if the value is changing from false to true and only for VNet-injected workspaces.
- `public_subnet_name` - (Optional) The name of the Public Subnet within the Virtual Network.
- `public_subnet_network_security_group_association_id` - (Optional) The resource ID of the azurerm\_subnet\_network\_security\_group\_association which is referred to by the public\_subnet\_name field.
- `private_subnet_name` - (Optional) The name of the Private Subnet within the Virtual Network.
- `private_subnet_network_security_group_association_id` - (Optional) The resource ID of the azurerm\_subnet\_network\_security\_group\_association which is referred to by the private\_subnet\_name field.
- `storage_account_name` - (Optional) Default Databricks File Storage account name. Defaults to a randomized name.
- `storage_account_sku_name` - (Optional) Storage account SKU name. Defaults to 'Standard\_GRS'.
- `virtual_network_id` - (Optional) The ID of a Virtual Network where the Databricks Cluster should be created. More information about VNet injection can be found [here](https://learn.microsoft.com/en-us/azure/databricks/administration-guide/cloud-configurations/azure/vnet-inject).
- `vnet_address_prefix` - (Optional) Address prefix for Managed virtual network. Defaults to '10.139'.

Note: Databricks requires that a network security group is associated with the public and private subnets when a virtual\_network\_id has been defined.

Type:

```hcl
object({
    machine_learning_workspace_id                        = optional(string, null)
    nat_gateway_name                                     = optional(string)
    public_ip_name                                       = optional(string)
    no_public_ip                                         = optional(bool, false)
    public_subnet_name                                   = optional(string, null)
    public_subnet_network_security_group_association_id  = optional(string, null)
    private_subnet_name                                  = optional(string, null)
    private_subnet_network_security_group_association_id = optional(string, null)
    storage_account_name                                 = optional(string, null) # Defaults to a randomized name
    storage_account_sku_name                             = optional(string, "Standard_GRS")
    virtual_network_id                                   = optional(string, null)
    vnet_address_prefix                                  = optional(string)
  })
```

Default: `{}`

### <a name="input_customer_managed_key_enabled"></a> [customer\_managed\_key\_enabled](#input\_customer\_managed\_key\_enabled)

Description:   Is the workspace enabled for customer managed key encryption? If true this enables the Managed Identity for the managed storage account.  
  Possible values are true or false. Defaults to false.  
  This field is only valid if the Databricks Workspace sku is set to premium.

Type: `bool`

Default: `false`

### <a name="input_dbfs_root_cmk_key_vault_key_id"></a> [dbfs\_root\_cmk\_key\_vault\_key\_id](#input\_dbfs\_root\_cmk\_key\_vault\_key\_id)

Description:     The ID of the customer-managed key for DBFS root.  
    This is required when customer\_managed\_key\_enabled is set to true.

Type: `string`

Default: `null`

### <a name="input_diagnostic_settings"></a> [diagnostic\_settings](#input\_diagnostic\_settings)

Description: A map of diagnostic settings to create on the storage account. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the diagnostic setting. One will be generated if not set, however this will not be unique if you want to create multiple diagnostic setting resources.
- `log_categories` - (Optional) A set of log categories to send to the log analytics workspace. Defaults to `[]`.
- `log_groups` - (Optional) A set of log groups to send to the log analytics workspace. Defaults to `["allLogs"]`.
- `metric_categories` - (Optional) A set of metric categories to send to the log analytics workspace. Defaults to `["AllMetrics"]`.
- `log_analytics_destination_type` - (Optional) The destination type for the diagnostic setting. Possible values are `Dedicated` and `AzureDiagnostics`. Defaults to `Dedicated`.
- `workspace_resource_id` - (Optional) The resource ID of the log analytics workspace to send logs and metrics to.
- `storage_account_resource_id` - (Optional) The resource ID of the storage account to send logs and metrics to.
- `event_hub_authorization_rule_resource_id` - (Optional) The resource ID of the event hub authorization rule to send logs and metrics to.
- `event_hub_name` - (Optional) The name of the event hub. If none is specified, the default event hub will be selected.
- `marketplace_partner_resource_id` - (Optional) The full ARM resource ID of the Marketplace resource to which you would like to send Diagnostic LogsLogs.

Type:

```hcl
map(object({
    name                                     = optional(string, null)
    log_categories                           = optional(set(string), [])
    log_groups                               = optional(set(string), ["allLogs"])
    metric_categories                        = optional(set(string), ["AllMetrics"])
    log_analytics_destination_type           = optional(string, "Dedicated")
    workspace_resource_id                    = optional(string, null)
    storage_account_resource_id              = optional(string, null)
    event_hub_authorization_rule_resource_id = optional(string, null)
    event_hub_name                           = optional(string, null)
    marketplace_partner_resource_id          = optional(string, null)
  }))
```

Default: `{}`

### <a name="input_enable_telemetry"></a> [enable\_telemetry](#input\_enable\_telemetry)

Description: This variable controls whether or not telemetry is enabled for the module.  
For more information see <https://aka.ms/avm/telemetryinfo>.  
If it is set to false, then no telemetry will be collected.

Type: `bool`

Default: `true`

### <a name="input_infrastructure_encryption_enabled"></a> [infrastructure\_encryption\_enabled](#input\_infrastructure\_encryption\_enabled)

Description:   By default, Azure encrypts storage account data at rest. Infrastructure encryption adds a second layer of encryption to your storage account's data  
  Possible values are true or false. Defaults to false.  
  This field is only valid if the Databricks Workspace sku is set to premium.  
  Changing this forces a new resource to be created.

Type: `bool`

Default: `false`

### <a name="input_load_balancer_backend_address_pool_id"></a> [load\_balancer\_backend\_address\_pool\_id](#input\_load\_balancer\_backend\_address\_pool\_id)

Description: Resource ID of the Outbound Load balancer Backend Address Pool for Secure Cluster Connectivity (No Public IP) workspace. Changing this forces a new resource to be created.

Type: `string`

Default: `null`

### <a name="input_lock"></a> [lock](#input\_lock)

Description: The lock level to apply to the databricks workspace. Default is `None`. Possible values are `None`, `CanNotDelete`, and `ReadOnly`.

Type:

```hcl
object({
    name = optional(string, null)
    kind = optional(string, "None")
  })
```

Default: `null`

### <a name="input_managed_disk_cmk_key_vault_key_id"></a> [managed\_disk\_cmk\_key\_vault\_key\_id](#input\_managed\_disk\_cmk\_key\_vault\_key\_id)

Description:   Customer managed encryption properties for the Databricks Workspace managed disks.

  Once the Databricks Workspace is created, the managed disk encryption set must be added to the key vault access policy, this can be found in the managed resource group under the name 'databricks-encryption-set-<workspace-name>'.  
  This resource ID can be used to create a Key Vault access policy for the managed disk encryption set. RBA role 'Key Vault Crypto Officer' is required to create the access policy.  
  The Key Vault access policy should be created with the following permissions: 'Get', 'Wrap Key', 'Unwrap Key', 'Sign', 'Verify', 'List'. or Key Vault Crypto User role.

  NOTE: Disabling CMK for Disk is currently not supported. If you want to disable Managed Services, you must delete the workspace and create a new one.

Type: `string`

Default: `null`

### <a name="input_managed_disk_cmk_rotation_to_latest_version_enabled"></a> [managed\_disk\_cmk\_rotation\_to\_latest\_version\_enabled](#input\_managed\_disk\_cmk\_rotation\_to\_latest\_version\_enabled)

Description: Whether customer managed keys for disk encryption will automatically be rotated to the latest version. Optional.

Type: `bool`

Default: `false`

### <a name="input_managed_resource_group_name"></a> [managed\_resource\_group\_name](#input\_managed\_resource\_group\_name)

Description:   The name of the resource group where Azure should place the managed Databricks resources.  
  Changing this forces a new resource to be created.

  NOTE: Make sure that this field is unique if you have multiple Databrick Workspaces deployed in your subscription and choose to not have the managed\_resource\_group\_name auto generated by the Azure Resource Provider. Having multiple Databrick Workspaces deployed in the same subscription with the same manage\_resource\_group\_name may result in some resources that cannot be deleted.

Type: `string`

Default: `null`

### <a name="input_managed_services_cmk_key_vault_key_id"></a> [managed\_services\_cmk\_key\_vault\_key\_id](#input\_managed\_services\_cmk\_key\_vault\_key\_id)

Description:     Databricks Workspace Customer Managed Keys for Managed Services(e.g. Notebooks and Artifacts).

    To find the correct Object ID to use for the Key vault access policy for managed services, follow these steps:  
    1. Go to portal -> Azure Active Directory.  
    2. In the search your tenant bar enter the value 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d.  
    3. You will see under Enterprise application results AzureDatabricks, click on the AzureDatabricks search result.  
    4. This will open the Enterprise Application overview blade where you will see three values, the name of the application, the application ID, and the object ID.  
    5. The value you want is the object ID.  
    6. The Key Vault access policy should be created with the following permissions: 'Get', 'Wrap Key', 'Unwrap Key', 'Sign', 'Verify', 'List'. or Key Vault Crypto User role.

    NOTE: Disabling Managed Services (aka CMK for Notebook) is currently not supported. If you want to disable Managed Services, you must delete the workspace and create a new one.

Type: `string`

Default: `null`

### <a name="input_network_security_group_rules_required"></a> [network\_security\_group\_rules\_required](#input\_network\_security\_group\_rules\_required)

Description:   Does the data plane (clusters) to control plane communication happen over private link endpoint only or publicly?  
  Possible values AllRules, NoAzureDatabricksRules or NoAzureServiceRules.  
  Required when public\_network\_access\_enabled is set to false.

Type: `string`

Default: `null`

### <a name="input_private_endpoints"></a> [private\_endpoints](#input\_private\_endpoints)

Description: A map of private endpoints to create on this resource. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the private endpoint. One will be generated if not set.
- `role_assignments` - (Optional) A map of role assignments to create on the private endpoint. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time. See `var.role_assignments` for more information.
- `lock` - (Optional) The lock level to apply to the private endpoint. Default is `None`. Possible values are `None`, `CanNotDelete`, and `ReadOnly`.
- `tags` - (Optional) A mapping of tags to assign to the private endpoint.
- `subnet_resource_id` - The resource ID of the subnet to deploy the private endpoint in.
- `private_dns_zone_group_name` - (Optional) The name of the private DNS zone group. One will be generated if not set.
- `private_dns_zone_resource_ids` - (Optional) A set of resource IDs of private DNS zones to associate with the private endpoint. If not set, no zone groups will be created and the private endpoint will not be associated with any private DNS zones. DNS records must be managed external to this module.
- `application_security_group_resource_ids` - (Optional) A map of resource IDs of application security groups to associate with the private endpoint. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.
- `private_service_connection_name` - (Optional) The name of the private service connection. One will be generated if not set.
- `network_interface_name` - (Optional) The name of the network interface. One will be generated if not set.
- `location` - (Optional) The Azure location where the resources will be deployed. Defaults to the location of the resource group.
- `resource_group_name` - (Optional) The resource group where the resources will be deployed. Defaults to the resource group of this resource.
- `ip_configurations` - (Optional) A map of IP configurations to create on the private endpoint. If not specified the platform will create one. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.
  - `name` - The name of the IP configuration.
  - `private_ip_address` - The private IP address of the IP configuration.

Type:

```hcl
map(object({
    name = optional(string, null)
    role_assignments = optional(map(object({
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
    })), {})
    lock = optional(object({
      kind = string
      name = optional(string, null)
    }), null)
    tags                                    = optional(map(string), null)
    subnet_resource_id                      = string
    private_dns_zone_group_name             = optional(string, "default")
    private_dns_zone_resource_ids           = optional(set(string), [])
    application_security_group_associations = optional(map(string), {})
    private_service_connection_name         = optional(string, null)
    network_interface_name                  = optional(string, null)
    location                                = optional(string, null)
    resource_group_name                     = optional(string, null)
    ip_configurations = optional(map(object({
      name               = string
      private_ip_address = string
    })), {})
  }))
```

Default: `{}`

### <a name="input_public_network_access_enabled"></a> [public\_network\_access\_enabled](#input\_public\_network\_access\_enabled)

Description:   Allow public access for accessing workspace. Set value to false to access workspace only via private link endpoint.  
  Possible values include true or false. Defaults to true.  
  Creation of workspace with PublicNetworkAccess property set to false is only supported for VNet Injected workspace.

Type: `bool`

Default: `true`

### <a name="input_role_assignments"></a> [role\_assignments](#input\_role\_assignments)

Description: A map of role assignments to create on this resource. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
- `principal_id` - The ID of the principal to assign the role to.
- `description` - The description of the role assignment.
- `skip_service_principal_aad_check` - If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
- `condition` - The condition which will be used to scope the role assignment.
- `condition_version` - The version of the condition syntax. Valid values are '2.0'.

> Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.

Type:

```hcl
map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
  }))
```

Default: `{}`

### <a name="input_tags"></a> [tags](#input\_tags)

Description: The map of tags to be applied to the resource

Type: `map(any)`

Default: `{}`

### <a name="input_virtual_network_peering"></a> [virtual\_network\_peering](#input\_virtual\_network\_peering)

Description: A map of virtual network peering configurations. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time.

- `name` - (Optional) Specifies the name of the Databricks Virtual Network Peering resource. Changing this forces a new resource to be created.
- `resource_group_name` - (Optional) The name of the Resource Group in which the Databricks Virtual Network Peering should exist.  Defaults to the resource group of the databricks instance.
- `remote_address_space_prefixes` - (Required) A list of address blocks reserved for the remote virtual network in CIDR notation. Changing this forces a new resource to be created.
- `remote_virtual_network_id` - (Required) The ID of the remote virtual network. Changing this forces a new resource to be created.
- `allow_virtual_network_access` - (Optional) Can the VMs in the local virtual network space access the VMs in the remote virtual network space? Defaults to true.
- `allow_forwarded_traffic` - (Optional) Can the forwarded traffic from the VMs in the local virtual network be forwarded to the remote virtual network? Defaults to false.
- `allow_gateway_transit` - (Optional) Can the gateway links be used in the remote virtual network to link to the Databricks virtual network? Defaults to false.
- `use_remote_gateways` - (Optional) Can remote gateways be used on the Databricks virtual network? Defaults to false.  
                          If the use\_remote\_gateways is set to true, and allow\_gateway\_transit on the remote peering is also true, the virtual network will use the gateways of the remote virtual network for transit. Only one peering can have this flag set to true. use\_remote\_gateways cannot be set if the virtual network already has a gateway.

Type:

```hcl
map(object({
    name                          = optional(string, null)
    resource_group_name           = optional(string, null)
    remote_address_space_prefixes = list(string)
    remote_virtual_network_id     = string
    allow_virtual_network_access  = optional(bool, true)
    allow_forwarded_traffic       = optional(bool, false)
    allow_gateway_transit         = optional(bool, false)
    use_remote_gateways           = optional(bool, false)
  }))
```

Default: `{}`

## Outputs

The following outputs are exported:

### <a name="output_databricks_id"></a> [databricks\_id](#output\_databricks\_id)

Description: The ID of the Databricks Workspace in the Azure management plane.

### <a name="output_databricks_virtual_network_peering_address_space_prefixes"></a> [databricks\_virtual\_network\_peering\_address\_space\_prefixes](#output\_databricks\_virtual\_network\_peering\_address\_space\_prefixes)

Description: A list of address blocks reserved for this virtual network in CIDR notation.

### <a name="output_databricks_virtual_network_peering_id"></a> [databricks\_virtual\_network\_peering\_id](#output\_databricks\_virtual\_network\_peering\_id)

Description: The IDs of the internal Virtual Networks used by the DataBricks Workspace.

### <a name="output_databricks_virtual_network_peering_virtual_network_id"></a> [databricks\_virtual\_network\_peering\_virtual\_network\_id](#output\_databricks\_virtual\_network\_peering\_virtual\_network\_id)

Description: The ID of the internal Virtual Network used by the DataBricks Workspace.

### <a name="output_databricks_workspace_disk_encryption_set_id"></a> [databricks\_workspace\_disk\_encryption\_set\_id](#output\_databricks\_workspace\_disk\_encryption\_set\_id)

Description: The ID of Managed Disk Encryption Set created by the Databricks Workspace.

### <a name="output_databricks_workspace_id"></a> [databricks\_workspace\_id](#output\_databricks\_workspace\_id)

Description: The unique identifier of the databricks workspace in Databricks control plane.

### <a name="output_databricks_workspace_managed_disk_identity"></a> [databricks\_workspace\_managed\_disk\_identity](#output\_databricks\_workspace\_managed\_disk\_identity)

Description:   A managed\_disk\_identity block as documented below

  - `principal_id` - The principal UUID for the internal databricks disks identity needed to provide access to the workspace for enabling Customer Managed Keys.
  - `tenant_id` - The UUID of the tenant where the internal databricks disks identity was created.
  - `type` - The type of the internal databricks disks identity.

### <a name="output_databricks_workspace_managed_resource_group_id"></a> [databricks\_workspace\_managed\_resource\_group\_id](#output\_databricks\_workspace\_managed\_resource\_group\_id)

Description: The ID of the Managed Resource Group created by the Databricks Workspace.

### <a name="output_databricks_workspace_storage_account_identity"></a> [databricks\_workspace\_storage\_account\_identity](#output\_databricks\_workspace\_storage\_account\_identity)

Description:   A storage\_account\_identity block as documented below

  - `principal_id` - The principal UUID for the internal databricks storage account needed to provide access to the workspace for enabling Customer Managed Keys.
  - `tenant_id` - The UUID of the tenant where the internal databricks storage account was created.
  - `type` - The type of the internal databricks storage account.

### <a name="output_databricks_workspace_url"></a> [databricks\_workspace\_url](#output\_databricks\_workspace\_url)

Description: The workspace URL which is of the format 'adb-{workspaceId}.{random}.azuredatabricks.net'.

### <a name="output_name"></a> [name](#output\_name)

Description: The name of the Databricks Workspace.

### <a name="output_private_endpoints"></a> [private\_endpoints](#output\_private\_endpoints)

Description: A map of private endpoints. The map key is the supplied input to var.private\_endpoints. The map value is the entire azurerm\_private\_endpoint resource.

### <a name="output_resource"></a> [resource](#output\_resource)

Description: This is the full output for the resource.

### <a name="output_resource_id"></a> [resource\_id](#output\_resource\_id)

Description: The ID of the Databricks Workspace in the Azure management plane.

### <a name="output_system_assigned_mi_principal_id"></a> [system\_assigned\_mi\_principal\_id](#output\_system\_assigned\_mi\_principal\_id)

Description: The principal ID of the system assigned managed identity.

## Modules

No modules.

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->