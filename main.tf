# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

resource "random_id" "randomized_names" {
  keepers = {
    adf_name = var.adf_name
  }
  byte_length = 4
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
  subscription_id = var.subscription_id
}

data "azurerm_client_config" "current" {}
# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "resources"
  location = "Sweden Central"
  tags = {
    environment = "dev"
  }
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "vn" {
  name                = "network"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
  tags = {
    environment = "dev"
  }
}
resource "azurerm_subnet" "subnet" {
  name                 = "subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vn.name
  address_prefixes     = ["10.0.1.0/24"]


}


resource "azurerm_key_vault" "key_vault" {
  name                       = "qjokv"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Create",
      "Delete",
      "Get",
      "Purge",
      "Recover",
      "Update",
      "GetRotationPolicy",
      "SetRotationPolicy"
    ]

    secret_permissions = [
      "Set",
      "Get",
      "List"
    ]
  }
}


resource "azurerm_storage_account" "storage_acc" {
  name                     = var.storage_acc_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true
}


resource "azurerm_storage_container" "containers" {
  for_each = toset(var.storage_container_names)

  name                  = each.value
  storage_account_name  = azurerm_storage_account.storage_acc.name
  container_access_type = "private"
}



resource "azurerm_mssql_server" "azure_sql" {
  name                = "qjo-server-test"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "swedencentral"
  version             = "12.0"

  minimum_tls_version = "1.2"

  public_network_access_enabled        = true
  outbound_network_restriction_enabled = false

  administrator_login          = var.azure_sql_admin_username
  administrator_login_password = var.azure_sql_admin_pass
  azuread_administrator {
    azuread_authentication_only = false
    login_username              = "yavor.lozev_gmail.com#EXT#@yavorlozevgmail.onmicrosoft.com"
    object_id                   = "5f088b92-1f52-4bb3-a061-4b0d66274597"
    tenant_id                   = "9dc905ca-6b24-47e5-840e-979840c7f474"
  }
}


resource "azurerm_mssql_database" "sqldb" {
  name         = "metadata-db"
  server_id    = azurerm_mssql_server.azure_sql.id
  collation    = "SQL_Latin1_General_CP1_CI_AS"
  license_type = "LicenseIncluded"
  max_size_gb  = 2
  sku_name     = "S0"
  enclave_type = "VBS"

  # prevent the possibility of accidental data loss
  # lifecycle {
  #   prevent_destroy = true
  # }
}

resource "azurerm_data_factory" "adf" {
  name                = "${var.adf_name}-${random_id.randomized_names.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  identity {
    type = "SystemAssigned"
  }

  vsts_configuration {
    account_name    = "qvkata-project"
    project_name    = "personal-project"
    repository_name = "data-factory"
    branch_name     = "main"
    root_folder     = "/"
    tenant_id       = data.azurerm_client_config.current.tenant_id
  }
}

resource "azurerm_role_assignment" "adf_storage_blob_contributor" {
  scope                            = azurerm_storage_account.storage_acc.id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azurerm_data_factory.adf.identity[0].principal_id
  skip_service_principal_aad_check = true

}



resource "azurerm_data_factory_linked_service_key_vault" "ls_kv" {
  name            = "qjo_kv"
  data_factory_id = azurerm_data_factory.adf.id
  key_vault_id    = azurerm_key_vault.key_vault.id
}

resource "azurerm_data_factory_linked_service_data_lake_storage_gen2" "ls_adls" {
  name                 = "qj_adls"
  data_factory_id      = azurerm_data_factory.adf.id
  use_managed_identity = true

  url = azurerm_storage_account.storage_acc.primary_dfs_endpoint
}


resource "azurerm_data_factory_linked_service_web" "ls_api" {
  name                = "qjo_api"
  data_factory_id     = azurerm_data_factory.adf.id
  authentication_type = "Anonymous"

  parameters = {
    base_url = ""
  }

  url = "@{linkedService().base_url}"
}

resource "azurerm_data_factory_linked_service_azure_sql_database" "ls_azure_sql" {
  name            = "qjo_azure_sql"
  data_factory_id = azurerm_data_factory.adf.id

  parameters = {
    domain_name = ""
    db_name     = ""
  }

  use_managed_identity = true

  connection_string = "Data Source=@{linkedService().domain_name};Initial Catalog=@{linkedService().db_name};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
}