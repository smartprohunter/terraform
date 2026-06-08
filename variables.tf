variable "subscription_id" {
  type        = string
  description = "susbsription for the azure account"
  sensitive   = true
}


variable "adf_name" {
  type        = string
  default     = "qjo-adf"
  description = "description"
}

variable "resource_group_location" {
  type        = string
  default     = "Sweden Central"
  description = "Azure region for the resource group and regional resources."
}

variable "tags" {
  type        = map(string)
  description = "Common tags applied to supported Azure resources."
  default = {
    environment = "dev"
  }
}

variable "storage_acc_name" {
  type        = string
  default     = "qjostorageacc"
  description = "description"
}

variable "storage_container_names" {
  type    = list(string)
  default = ["watermarks", "source", "raw"]
}


variable "azure_sql_admin_pass" {
  type      = string
  sensitive = true

}

variable "azure_sql_admin_username" {
  type      = string
  sensitive = true

}

variable "azure_sql_ad_admin_login_username" {
  type        = string
  description = "Microsoft Entra login username to configure as Azure SQL administrator."
  sensitive   = true
}

variable "azure_sql_ad_admin_object_id" {
  type        = string
  description = "Object ID of the Microsoft Entra user or group to configure as Azure SQL administrator."
  sensitive   = true
}
