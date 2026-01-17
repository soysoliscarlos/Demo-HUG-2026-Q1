# #############################################
# Virtual Network (VNet)
# #############################################

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet_address_space

  tags = local.etiquetas_comunes
}

# #############################################
# Subnets
# #############################################

resource "azurerm_subnet" "subnet" {
  for_each = var.subnets

  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = each.value.address_prefixes

  # Configuración opcional para service endpoints
  service_endpoints = lookup(each.value, "service_endpoints", [])

  # Configuración opcional para delegación de subnet
  dynamic "delegation" {
    for_each = lookup(each.value, "delegation", null) != null ? [each.value.delegation] : []
    content {
      name = delegation.value.name

      service_delegation {
        name    = delegation.value.service_delegation.name
        actions = delegation.value.service_delegation.actions
      }
    }
  }
}

# #############################################
# Network Security Group (NSG)
# #############################################

resource "azurerm_network_security_group" "nsg" {
  for_each = var.subnets

  name                = "${each.value.name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = local.etiquetas_comunes
}

# #############################################
# NSG Association con Subnets
# #############################################

resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  for_each = var.subnets

  subnet_id                 = azurerm_subnet.subnet[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
}
