resource "azurerm_storage_account" "storage" {
  name                     = lower("${random_string.prefix.result}${var.storage_account_name}")
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Habilitar acceso de red privado
  # public_network_access_enabled = true
  public_network_access_enabled = false

  tags = local.etiquetas_comunes
}

resource "azurerm_storage_container" "container" {
  name                  = lower(var.container_name)
  storage_account_id    = azurerm_storage_account.storage.id
  container_access_type = var.container_access_type
}
