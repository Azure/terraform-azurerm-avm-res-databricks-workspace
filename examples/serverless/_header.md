# Serverless example

This example deploys an Azure Databricks workspace configured with Unity Catalog, which is required to enable Azure Databricks Serverless SQL and Serverless Compute.

Unity Catalog is enabled by setting `default_catalog.initial_type = "UnityCatalog"`. An Access Connector with a system-assigned managed identity is also deployed and linked to the workspace, as it is required for Unity Catalog federated identity access.

> **Note:** Once Unity Catalog is enabled (`UnityCatalog` initial type), it cannot be reverted without recreating the workspace. This setting requires a `premium` SKU.
