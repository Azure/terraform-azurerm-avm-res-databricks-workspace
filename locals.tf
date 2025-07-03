locals {
  resource_group_location            = try(data.azurerm_resource_group.parent.location, null)
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"

  # Create ordered list of private endpoint keys to ensure sequential creation
  private_endpoint_keys = keys(var.private_endpoints)
  private_endpoint_dependencies = {
    for idx, key in local.private_endpoint_keys : key => idx > 0 ? [local.private_endpoint_keys[idx - 1]] : []
  }
}

locals {
  private_endpoint_application_security_group_associations = { for assoc in flatten([
    for pe_k, pe_v in var.private_endpoints : [
      for asg_k, asg_v in pe_v.application_security_group_associations : {
        asg_key         = asg_k
        pe_key          = pe_k
        asg_resource_id = asg_v
      }
    ]
  ]) : "${assoc.pe_key}-${assoc.asg_key}" => assoc }
}
