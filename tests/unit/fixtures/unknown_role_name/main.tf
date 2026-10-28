resource "terraform_data" "role_assignment_name" {
  input = "00000000-0000-0000-0000-000000000007"
}

module "workspace" {
  source = "../../../.."

  location            = "eastus"
  name                = "unit-databricks"
  resource_group_name = "rg-unit"
  sku                 = "premium"
  enable_telemetry    = false
  private_endpoints = {
    ui = {
      subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/unit/subnets/endpoints"
      subresource_name   = "databricks_ui_api"
      role_assignments = {
        reader = {
          name                       = terraform_data.role_assignment_name.output
          principal_id               = "00000000-0000-0000-0000-000000000008"
          role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000003/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        }
      }
    }
  }
  private_endpoints_manage_dns_zone_group = var.manage_dns_zone_group
}

output "private_endpoints" {
  value = module.workspace.private_endpoints
}
