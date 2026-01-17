resource "azurerm_resource_group" "rg" {
  name     = "${random_string.prefix.result}-${var.resource_group_name}"
  location = var.location
  tags     = local.etiquetas_comunes
}
