# #############################################
# Variables - Configuración de despliegue y etiquetado
# #############################################
variable "environment" {
  description = "Environment identifier used for resource tagging."
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}

# ###############################
# Variables - Resource Group RAC
# ###############################
variable "resource_group_name" {
  description = "Name of the resource group for the RAG workload."
  type        = string
}

variable "location" {
  description = "Azure region to deploy resources."
  type        = string
  default     = "eastus"
}

# #################################
# Variables - Virtual Network (VNet)
# #################################
variable "vnet_name" {
  description = "Name of the Virtual Network."
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnets" {
  description = "Map of subnets to create within the VNet."
  type = map(object({
    name              = string
    address_prefixes  = list(string)
    service_endpoints = optional(list(string), [])
    delegation = optional(object({
      name = string
      service_delegation = object({
        name    = string
        actions = list(string)
      })
    }))
  }))
  default = {}
}

# #################################
# Variables - Storage Account RAC
# #################################
variable "storage_account_name" {
  description = "Name of the storage account used by the RAG workload."
  type        = string
}

variable "container_name" {
  description = "Name of the storage container within the storage account."
  type        = string
}

variable "container_access_type" {
  description = "Access type for the storage container (private, blob, or container)."
  type        = string
  default     = "private"
}

# #############################
# Variables - Key Vault del RAC
# #############################
variable "key_vault_name" {
  description = "Name for the Azure Key Vault."
  type        = string
}

variable "key_vault_sku" {
  description = "Key Vault SKU (standard or premium)."
  type        = string
  default     = "standard"
}

