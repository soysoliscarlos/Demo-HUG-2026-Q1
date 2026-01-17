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
# Outputs - Azure Bastion
# #############################################

output "bastion_host_id" {
  description = "ID of the Azure Bastion Host."
  value       = azurerm_bastion_host.bastion.id
}

output "bastion_host_name" {
  description = "Name of the Azure Bastion Host."
  value       = azurerm_bastion_host.bastion.name
}

output "bastion_public_ip" {
  description = "Public IP address of the Azure Bastion Host."
  value       = azurerm_public_ip.bastion.ip_address
}

# #############################################
# Outputs - Virtual Machine
# #############################################

output "vm_id" {
  description = "ID of the Virtual Machine."
  value       = azurerm_windows_virtual_machine.vm.id
}

output "vm_name" {
  description = "Name of the Virtual Machine."
  value       = azurerm_windows_virtual_machine.vm.name
}

output "vm_private_ip" {
  description = "Private IP address of the Virtual Machine."
  value       = azurerm_network_interface.vm.private_ip_address
}

output "vm_identity_principal_id" {
  description = "Principal ID of the VM's system-assigned identity."
  value       = azurerm_windows_virtual_machine.vm.identity[0].principal_id
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
