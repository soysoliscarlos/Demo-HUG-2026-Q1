# #############################################
# Private DNS Zones
# #############################################

# DNS Zone para Storage Account (Blob)
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.etiquetas_comunes
}

# DNS Zone para Storage Account (File)
resource "azurerm_private_dns_zone" "file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.etiquetas_comunes
}

# DNS Zone para Key Vault
resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.etiquetas_comunes
}

# #############################################
# Virtual Network Links para Private DNS Zones
# #############################################

resource "azurerm_private_dns_zone_virtual_network_link" "blob_link" {
  name                  = "blob-vnet-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
  tags                  = local.etiquetas_comunes
}

resource "azurerm_private_dns_zone_virtual_network_link" "file_link" {
  name                  = "file-vnet-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.file.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
  tags                  = local.etiquetas_comunes
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault_link" {
  name                  = "keyvault-vnet-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
  tags                  = local.etiquetas_comunes
}


# #############################################
# Private Endpoint - Storage Account (Blob)
# #############################################

resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-${azurerm_storage_account.storage.name}-blob"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet["subnet_private_endpoints"].id

  private_service_connection {
    name                           = "psc-${azurerm_storage_account.storage.name}-blob"
    private_connection_resource_id = azurerm_storage_account.storage.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdns-group-blob"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }

  tags = local.etiquetas_comunes
}

# #############################################
# Private Endpoint - Storage Account (File)
# #############################################

resource "azurerm_private_endpoint" "storage_file" {
  name                = "pe-${azurerm_storage_account.storage.name}-file"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet["subnet_private_endpoints"].id

  private_service_connection {
    name                           = "psc-${azurerm_storage_account.storage.name}-file"
    private_connection_resource_id = azurerm_storage_account.storage.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdns-group-file"
    private_dns_zone_ids = [azurerm_private_dns_zone.file.id]
  }

  tags = local.etiquetas_comunes
}

# #############################################
# Private Endpoint - Key Vault
# #############################################

resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-${azurerm_key_vault.kv.name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet["subnet_private_endpoints"].id

  private_service_connection {
    name                           = "psc-${azurerm_key_vault.kv.name}"
    private_connection_resource_id = azurerm_key_vault.kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdns-group-keyvault"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault.id]
  }

  tags = local.etiquetas_comunes
}
