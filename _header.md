# terraform-azurerm-res-databricks-workspace

Manages a Databricks Workspace.

The workspace resource is provisioned through the [`azapi`](https://registry.terraform.io/providers/Azure/azapi/latest) provider so that creation-only properties such as `computeMode` and `defaultCatalog` (which power Azure Databricks Serverless SQL and Serverless Compute) can be sent in the initial PUT body. All other resources (access connectors, virtual network peerings, private endpoints, role assignments, diagnostic settings, locks, customer-managed key bindings) remain on the `azurerm` provider.

> **Upgrading from v0.4.x or earlier:** The Databricks Workspace resource type has changed from `azurerm_databricks_workspace.this` to `azapi_resource.this`. Apply a one-time state migration with `removed{}` + `import{}` blocks before your first `terraform apply` on this version.

## State migration

In your root module, add the following blocks for every instance of this module you consume and then run `terraform plan` + `terraform apply` once. The blocks can be removed after a clean apply.

```hcl
removed {
  from = module.databricks.azurerm_databricks_workspace.this

  lifecycle {
    destroy = false
  }
}

import {
  to = module.databricks.azapi_resource.this
  id = module.databricks.databricks_id # or the workspace ARM resource id string
}
```
