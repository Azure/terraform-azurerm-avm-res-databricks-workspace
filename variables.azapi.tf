variable "ignore_body_changes" {
  type = object({
    authorization_locks            = optional(list(string), [])
    authorization_role_assignments = optional(list(string), [])
    databricks_workspaces          = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Body-relative dot-notation paths whose changes AzAPI ignores. Configuration changes at ignored paths are not sent to Azure until the paths are removed. Changes take effect only after apply. Non-empty values require Terraform 1.11 or later.

- `authorization_locks` - Ignored body paths for private endpoint locks.
- `authorization_role_assignments` - Ignored body paths for private endpoint role assignments.
- `databricks_workspaces` - Ignored body paths for the Databricks Workspace.
DESCRIPTION
  nullable    = false
}

variable "resource_types" {
  type = object({
    authorization_locks            = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
    databricks_workspaces          = optional(string, "Microsoft.Databricks/workspaces@2026-01-01")
  })
  default     = {}
  description = <<DESCRIPTION
AzAPI resource types and API versions used by the module.

- `authorization_locks` - Resource type and API version for private endpoint locks.
- `authorization_role_assignments` - Resource type and API version for private endpoint role assignments.
- `databricks_workspaces` - Resource type and API version for the Databricks Workspace.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = <<DESCRIPTION
Retry configuration applied to the workspace and private endpoint extension resources. Defaults to `null` (provider defaults).

- `error_message_regex` - Error patterns that trigger a retry.
- `interval_seconds` - Initial retry interval in seconds.
- `max_interval_seconds` - Maximum retry interval in seconds.
DESCRIPTION
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
Per-operation timeouts applied to the workspace and private endpoint extension resources. Defaults to `null` (provider defaults). Values are Go duration strings, such as `30m`.

- `create` - Timeout for create operations.
- `read` - Timeout for read operations.
- `update` - Timeout for update operations.
- `delete` - Timeout for delete operations.
DESCRIPTION
}
