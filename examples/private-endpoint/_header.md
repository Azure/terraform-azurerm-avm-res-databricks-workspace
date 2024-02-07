# VNet injection example

The default deployment of Azure Databricks is a fully managed service on Azure: all compute plane resources, including a VNet that all clusters will be associated with, are deployed to a locked resource group. If you require network customization, however, you can deploy Azure Databricks compute plane resources in your own virtual network (sometimes called VNet injection), enabling you to:

- Connect Azure Databricks to other Azure services (such as Azure Storage) in a more secure manner using service endpoints or private endpoints.
- Connect to on-premises data sources for use with Azure Databricks, taking advantage of user-defined routes.
- Connect Azure Databricks to a network virtual appliance to inspect all outbound traffic and take actions according to allow and deny rules, by using user-defined routes.
- Configure Azure Databricks to use custom DNS.
- Configure network security group (NSG) rules to specify egress traffic restrictions.
- Deploy Azure Databricks clusters in your existing VNet.
