variable "subscription_id" {
  type = string
  #   description = "susbsriptions for the azure account"
  sensitive = true
}


variable "adf_name" {
  type        = string
  default     = "qjo-adf"
  description = "description"
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