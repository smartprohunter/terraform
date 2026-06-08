# Azure Data Platform Terraform

Terraform for a small Azure data platform stack built around Azure Data Factory, ADLS Gen2, Azure SQL, and Key Vault.

## Resources

This configuration creates:

- Resource group
- Virtual network and subnet
- Key Vault
- ADLS Gen2 storage account
- Private storage containers
- Azure SQL Server
- Azure SQL Database
- Azure Data Factory with system-assigned managed identity
- ADF linked service for Key Vault
- ADF linked service for ADLS Gen2 using managed identity
- ADF linked service for Web API with dynamic `base_url`
- ADF linked service for Azure SQL using managed identity
- Role assignment giving ADF `Storage Blob Data Contributor` on the storage account

Common tags from `var.tags` are applied to supported resources.

## Requirements

- Terraform
- Azure CLI
- Azure subscription permissions to create resources and role assignments

Login and select subscription:

```bash
az login
az account set --subscription "<subscription-id>"
```

## Variables

Required local values:

```hcl
subscription_id = "<subscription-id>"

azure_sql_admin_username = "<sql-admin-username>"
azure_sql_admin_pass     = "<sql-admin-password>"

azure_sql_ad_admin_login_username = "<entra-admin-user-principal-name>"
azure_sql_ad_admin_object_id      = "<entra-admin-object-id>"
```

Optional values:

```hcl
adf_name                = "qjo-adf"
resource_group_location = "Sweden Central"
storage_acc_name        = "qjostorageacc"
storage_container_names = ["watermarks", "source", "raw"]

tags = {
  environment = "dev"
}
```

Keep these in `terraform.tfvars`. This file is ignored by git because it can contain secrets and personal identifiers.

## Commands

Initialize:

```bash
terraform init
```

Format:

```bash
terraform fmt
```

Validate:

```bash
terraform validate
```

Preview:

```bash
terraform plan
```

Apply:

```bash
terraform apply
```

Destroy:

```bash
terraform destroy
```

## Managed Identity Notes

Data Factory has a system-assigned managed identity:

```hcl
identity {
  type = "SystemAssigned"
}
```

That identity is used for:

- ADLS Gen2 linked service auth
- Azure SQL linked service auth
- Storage role assignment

If `terraform apply` fails because the ADF identity principal ID is not available yet, apply ADF first, then run a normal apply:

```bash
terraform apply -target=azurerm_data_factory.adf
terraform apply
```

`skip_service_principal_aad_check = true` is enabled on the storage role assignment to avoid Azure AD replication timing issues for newly created identities.

## Azure SQL Entra Admin

The SQL Server config uses both SQL auth and Microsoft Entra admin:

```hcl
administrator_login          = var.azure_sql_admin_username
administrator_login_password = var.azure_sql_admin_pass

azuread_administrator {
  azuread_authentication_only = false
  login_username              = var.azure_sql_ad_admin_login_username
  object_id                   = var.azure_sql_ad_admin_object_id
  tenant_id                   = data.azurerm_client_config.current.tenant_id
}
```

The Entra admin is needed so managed identities can be granted database access later. Creating the linked service does not automatically create database users. After deployment, connect as the Entra admin and grant access to the ADF managed identity as needed.

## Dynamic Linked Services

Web linked service URL is parameterized:

```hcl
parameters = {
  base_url = ""
}

url = "@{linkedService().base_url}"
```

Azure SQL linked service uses managed identity auth and dynamic server/database parameters:

```hcl
parameters = {
  domain_name = ""
  db_name     = ""
}

use_managed_identity = true

connection_string = "Data Source=@{linkedService().domain_name};Initial Catalog=@{linkedService().db_name};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
```
