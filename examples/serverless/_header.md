# Serverless example

This deploys a Databricks Serverless workspace by setting `compute_mode = "Serverless"`. The workspace has no Classic data plane: no managed resource group, no VNet, no public IP egress. `sku = "premium"` is required.

`compute_mode` is a creation-only property: it cannot be flipped from `Hybrid` to `Serverless` (or vice versa) on an existing workspace. Plan accordingly.
