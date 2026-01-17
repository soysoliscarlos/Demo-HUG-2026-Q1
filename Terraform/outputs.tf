output "resource_group_name" {
  description = "Name of the resource group hosting the RAG workload."
  value       = azurerm_resource_group.rg.name
}

output "storage_account_name" {
  description = "Name of the storage account for RAG artifacts."
  value       = azurerm_storage_account.storage.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault storing secrets for the RAG solution."
  value       = azurerm_key_vault.kv.vault_uri
}

# #############################################
# Outputs - Virtual Network
# #############################################

output "vnet_id" {
  description = "ID of the Virtual Network."
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  description = "Name of the Virtual Network."
  value       = azurerm_virtual_network.vnet.name
}

# #############################################
# Outputs - Private Endpoints
# #############################################

output "private_endpoint_storage_blob_id" {
  description = "ID of the Storage Account Blob private endpoint."
  value       = azurerm_private_endpoint.storage_blob.id
}

output "private_endpoint_storage_file_id" {
  description = "ID of the Storage Account File private endpoint."
  value       = azurerm_private_endpoint.storage_file.id
}

output "private_endpoint_keyvault_id" {
  description = "ID of the Key Vault private endpoint."
  value       = azurerm_private_endpoint.keyvault.id
}

# #############################################
# Outputs - Private DNS Zones
# #############################################

output "private_dns_zones" {
  description = "Map of Private DNS Zones created for private endpoints."
  value = {
    blob     = azurerm_private_dns_zone.blob.name
    file     = azurerm_private_dns_zone.file.name
    keyvault = azurerm_private_dns_zone.keyvault.name
  }
}
