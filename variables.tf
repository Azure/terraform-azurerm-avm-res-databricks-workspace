variable "name" {
  type        = string
  description = "Specifies the name of the Databricks Workspace resource. Changing this forces a new resource to be created."

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,64}$", var.name))
    error_message = "The name must be 1-64 characters long and can only include alphanumeric characters, underscores, and hyphens."
  }
}

variable "resource_group_name" {
  type        = string
  description = "The name of the Resource Group in which the Databricks Workspace should exist. Changing this forces a new resource to be created."
}

variable "sku" {
  type        = string
  description = <<DESCRIPTION
  The 'sku' value must be one of 'standard', 'premium', or 'trial'.
  NOTE: Downgrading to a trial sku from a standard or premium sku will force a new resource to be created.
  DESCRIPTION

  validation {
    condition     = can(regex("^(standard|premium|trial)$", lower(var.sku)))
    error_message = "The 'sku' value must be one of 'standard', 'premium', or 'trial'."
  }
}

variable "access_connector" {
  type = map(object({
    name                = string
    resource_group_name = optional(string, null)
    location            = optional(string, null)
    identity = optional(object({
      type         = string
      identity_ids = optional(list(string))
    }))
    tags = optional(map(string))
  }))
  default     = {}
  description = <<DESCRIPTION

Configuration options for the Databricks Access Connector resource. This map includes the following attributes:

- `name` (Required): Specifies the name of the Databricks Access Connector resource. Changing this forces a new resource to be created.
- `resource_group_name` (Optional): The name of the Resource Group in which the Databricks Access Connector should exist. Defaults to the resource group of the databricks instance.
- `location` (Optional): Specifies the supported Azure location where the resource has to be created. Defaults to the location of the databricks instance.
- `identity` (Optional): An identity block. This block supports the following:
  - `type` (Required): Specifies the type of Managed Service Identity that should be configured on the Databricks Access Connector. Possible values include SystemAssigned or UserAssigned.
  - `identity_ids` (Optional): Specifies a list of User Assigned Managed Identity IDs to be assigned to the Databricks Access Connector. Only one User Assigned Managed Identity ID is supported per Databricks Access Connector resource. Note: identity_ids are required when type is set to UserAssigned.
- `tags` (Optional): A mapping of tags to assign to the resource.
  DESCRIPTION
}

variable "custom_parameters" {
  type = object({
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
  default     = {}
  description = <<DESCRIPTION
A map of custom parameters for configuring the Databricks Workspace. This object allows for detailed configuration, with each attribute representing a specific setting:

- `machine_learning_workspace_id` - (Optional) The ID of an Azure Machine Learning workspace to link with the Databricks workspace.
- `nat_gateway_name` - (Optional) Name of the NAT gateway for Secure Cluster Connectivity (No Public IP) workspace subnets. Defaults to 'nat-gateway'.
- `public_ip_name` - (Optional) Name of the Public IP for No Public IP workspace with managed vNet. Defaults to 'nat-gw-public-ip'.
- `no_public_ip` - (Optional) Specifies whether public IP Addresses are not allowed. Defaults to false. Note: Updating this parameter is only allowed if the value is changing from false to true and only for VNet-injected workspaces.
- `public_subnet_name` - (Optional) The name of the Public Subnet within the Virtual Network.
- `public_subnet_network_security_group_association_id` - (Optional) The resource ID of the azurerm_subnet_network_security_group_association which is referred to by the public_subnet_name field.
- `private_subnet_name` - (Optional) The name of the Private Subnet within the Virtual Network.
- `private_subnet_network_security_group_association_id` - (Optional) The resource ID of the azurerm_subnet_network_security_group_association which is referred to by the private_subnet_name field.
- `storage_account_name` - (Optional) Default Databricks File Storage account name. Defaults to a randomized name.
- `storage_account_sku_name` - (Optional) Storage account SKU name. Defaults to 'Standard_GRS'.
- `virtual_network_id` - (Optional) The ID of a Virtual Network where the Databricks Cluster should be created. More information about VNet injection can be found [here](https://learn.microsoft.com/en-us/azure/databricks/administration-guide/cloud-configurations/azure/vnet-inject).
- `vnet_address_prefix` - (Optional) Address prefix for Managed virtual network. Defaults to '10.139'.

Note: Databricks requires that a network security group is associated with the public and private subnets when a virtual_network_id has been defined.
DESCRIPTION

  validation {
    condition = var.custom_parameters.virtual_network_id == null || (var.custom_parameters.public_subnet_name != null &&
      var.custom_parameters.private_subnet_name != null &&
      var.custom_parameters.public_subnet_network_security_group_association_id != null &&
    var.custom_parameters.private_subnet_network_security_group_association_id != null)
    error_message = "'public_subnet_name', 'private_subnet_name', 'public_subnet_network_security_group_association_id' and 'private_subnet_network_security_group_association_id' must all have values if 'virtual_network_id' is set."
  }
}

variable "customer_managed_key_enabled" {
  type        = bool
  default     = false
  description = <<DESCRIPTION
  Is the workspace enabled for customer managed key encryption? If true this enables the Managed Identity for the managed storage account.
  Possible values are true or false. Defaults to false.
  This field is only valid if the Databricks Workspace sku is set to premium.
  DESCRIPTION

  validation {
    condition     = var.customer_managed_key_enabled == true || var.customer_managed_key_enabled == false
    error_message = "The customer_managed_key_enabled variable must be a boolean."
  }
}

variable "dbfs_root_cmk_key_vault_key_id" {
  type        = string
  default     = null
  description = <<DESCRIPTION
    The ID of the customer-managed key for DBFS root.
    This is required when customer_managed_key_enabled is set to true.
  DESCRIPTION
}

variable "diagnostic_settings" {
  type = map(object({
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
  default     = {}
  description = <<DESCRIPTION
A map of diagnostic settings to create on the storage account. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

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
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for _, v in var.diagnostic_settings : contains(["Dedicated", "AzureDiagnostics"], v.log_analytics_destination_type)])
    error_message = "Log analytics destination type must be one of: 'Dedicated', 'AzureDiagnostics'."
  }
  validation {
    condition = alltrue(
      [
        for _, v in var.diagnostic_settings :
        v.workspace_resource_id != null || v.storage_account_resource_id != null || v.event_hub_authorization_rule_resource_id != null || v.marketplace_partner_resource_id != null
      ]
    )
    error_message = "At least one of `workspace_resource_id`, `storage_account_resource_id`, `marketplace_partner_resource_id`, or `event_hub_authorization_rule_resource_id`, must be set."
  }
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}

variable "infrastructure_encryption_enabled" {
  type        = bool
  default     = false
  description = <<DESCRIPTION
  By default, Azure encrypts storage account data at rest. Infrastructure encryption adds a second layer of encryption to your storage account's data
  Possible values are true or false. Defaults to false.
  This field is only valid if the Databricks Workspace sku is set to premium.
  Changing this forces a new resource to be created.
  DESCRIPTION

  validation {
    condition     = var.infrastructure_encryption_enabled == true || var.infrastructure_encryption_enabled == false
    error_message = "The infrastructure_encryption_enabled variable must be a boolean."
  }
}

variable "load_balancer_backend_address_pool_id" {
  type        = string
  default     = null
  description = "Resource ID of the Outbound Load balancer Backend Address Pool for Secure Cluster Connectivity (No Public IP) workspace. Changing this forces a new resource to be created."
}

variable "location" {
  type        = string
  description = "Azure region where the resource should be deployed."
  nullable    = false
}

variable "lock" {
  type = object({
    name = optional(string, null)
    kind = optional(string, "None")
  })
  default     = null
  description = "The lock level to apply to the databricks workspace. Default is `None`. Possible values are `None`, `CanNotDelete`, and `ReadOnly`."

  validation {
    condition     = contains(["CanNotDelete", "ReadOnly", "None"], var.lock.kind)
    error_message = "The lock level must be one of: 'None', 'CanNotDelete', or 'ReadOnly'."
  }
}

variable "managed_disk_cmk_key_vault_key_id" {
  type        = string
  default     = null
  description = <<DESCRIPTION
  Customer managed encryption properties for the Databricks Workspace managed disks.

  Once the Databricks Workspace is created, the managed disk encryption set must be added to the key vault access policy, this can be found in the managed resource group under the name 'databricks-encryption-set-<workspace-name>'.
  This resource ID can be used to create a Key Vault access policy for the managed disk encryption set. RBA role 'Key Vault Crypto Officer' is required to create the access policy.
  The Key Vault access policy should be created with the following permissions: 'Get', 'Wrap Key', 'Unwrap Key', 'Sign', 'Verify', 'List'. or Key Vault Crypto User role.

  NOTE: Disabling CMK for Disk is currently not supported. If you want to disable Managed Services, you must delete the workspace and create a new one.
  DESCRIPTION
}

variable "managed_disk_cmk_rotation_to_latest_version_enabled" {
  type        = bool
  default     = false
  description = "Whether customer managed keys for disk encryption will automatically be rotated to the latest version. Optional."
}

variable "managed_resource_group_name" {
  type        = string
  default     = null
  description = <<DESCRIPTION
  The name of the resource group where Azure should place the managed Databricks resources.
  Changing this forces a new resource to be created.

  NOTE: Make sure that this field is unique if you have multiple Databrick Workspaces deployed in your subscription and choose to not have the managed_resource_group_name auto generated by the Azure Resource Provider. Having multiple Databrick Workspaces deployed in the same subscription with the same manage_resource_group_name may result in some resources that cannot be deleted.
  DESCRIPTION
}

variable "managed_services_cmk_key_vault_key_id" {
  type        = string
  default     = null
  description = <<DESCRIPTION
    Databricks Workspace Customer Managed Keys for Managed Services(e.g. Notebooks and Artifacts).

    To find the correct Object ID to use for the Key vault access policy for managed services, follow these steps:
    1. Go to portal -> Azure Active Directory.
    2. In the search your tenant bar enter the value 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d.
    3. You will see under Enterprise application results AzureDatabricks, click on the AzureDatabricks search result.
    4. This will open the Enterprise Application overview blade where you will see three values, the name of the application, the application ID, and the object ID.
    5. The value you want is the object ID.
    6. The Key Vault access policy should be created with the following permissions: 'Get', 'Wrap Key', 'Unwrap Key', 'Sign', 'Verify', 'List'. or Key Vault Crypto User role.


    NOTE: Disabling Managed Services (aka CMK for Notebook) is currently not supported. If you want to disable Managed Services, you must delete the workspace and create a new one.

  DESCRIPTION
}

variable "network_security_group_rules_required" {
  type        = string
  default     = null
  description = <<DESCRIPTION
  Does the data plane (clusters) to control plane communication happen over private link endpoint only or publicly?
  Possible values AllRules, NoAzureDatabricksRules or NoAzureServiceRules.
  Required when public_network_access_enabled is set to false.
  DESCRIPTION
}

variable "private_endpoints" {
  type = map(object({
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
  default     = {}
  description = <<DESCRIPTION
A map of private endpoints to create on this resource. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

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
DESCRIPTION
  nullable    = false
}

variable "public_network_access_enabled" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
  Allow public access for accessing workspace. Set value to false to access workspace only via private link endpoint.
  Possible values include true or false. Defaults to true.
  Creation of workspace with PublicNetworkAccess property set to false is only supported for VNet Injected workspace.
  DESCRIPTION
}

variable "role_assignments" {
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of role assignments to create on this resource. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
- `principal_id` - The ID of the principal to assign the role to.
- `description` - The description of the role assignment.
- `skip_service_principal_aad_check` - If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
- `condition` - The condition which will be used to scope the role assignment.
- `condition_version` - The version of the condition syntax. Valid values are '2.0'.

> Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.
DESCRIPTION
  nullable    = false
}

# tflint-ignore: terraform_unused_declarations
variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
}

variable "tags" {
  type        = map(any)
  default     = {}
  description = "The map of tags to be applied to the resource"
}

variable "virtual_network_peering" {
  type = map(object({
    name                          = optional(string, null)
    resource_group_name           = optional(string, null)
    remote_address_space_prefixes = list(string)
    remote_virtual_network_id     = string
    allow_virtual_network_access  = optional(bool, true)
    allow_forwarded_traffic       = optional(bool, false)
    allow_gateway_transit         = optional(bool, false)
    use_remote_gateways           = optional(bool, false)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of virtual network peering configurations. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time.

- `name` - (Optional) Specifies the name of the Databricks Virtual Network Peering resource. Changing this forces a new resource to be created.
- `resource_group_name` - (Optional) The name of the Resource Group in which the Databricks Virtual Network Peering should exist.  Defaults to the resource group of the databricks instance.
- `remote_address_space_prefixes` - (Required) A list of address blocks reserved for the remote virtual network in CIDR notation. Changing this forces a new resource to be created.
- `remote_virtual_network_id` - (Required) The ID of the remote virtual network. Changing this forces a new resource to be created.
- `allow_virtual_network_access` - (Optional) Can the VMs in the local virtual network space access the VMs in the remote virtual network space? Defaults to true.
- `allow_forwarded_traffic` - (Optional) Can the forwarded traffic from the VMs in the local virtual network be forwarded to the remote virtual network? Defaults to false.
- `allow_gateway_transit` - (Optional) Can the gateway links be used in the remote virtual network to link to the Databricks virtual network? Defaults to false.
- `use_remote_gateways` - (Optional) Can remote gateways be used on the Databricks virtual network? Defaults to false.
                          If the use_remote_gateways is set to true, and allow_gateway_transit on the remote peering is also true, the virtual network will use the gateways of the remote virtual network for transit. Only one peering can have this flag set to true. use_remote_gateways cannot be set if the virtual network already has a gateway.
DESCRIPTION
}
