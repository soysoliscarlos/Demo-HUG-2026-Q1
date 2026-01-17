# #############################################
# Virtual Network (VNet)
# #############################################

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.vnet_name}"
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
  for_each = { for k, v in var.subnets : k => v if k != "subnet_bastion" }

  name                = "${each.value.name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Reglas específicas para la subnet de VM (RDP desde Azure Bastion)
  dynamic "security_rule" {
    for_each = each.key == "subnet_vm" ? [1] : []
    content {
      name                       = "AllowRDPFromBastion"
      priority                   = 1001
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3389"
      source_address_prefix      = azurerm_subnet.subnet["subnet_bastion"].address_prefixes[0]
      destination_address_prefix = "*"
    }
  }

  tags = local.etiquetas_comunes
}

# #############################################
# NSG Association con Subnets
# #############################################

resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  for_each = { for k, v in var.subnets : k => v if k != "subnet_bastion" }

  subnet_id                 = azurerm_subnet.subnet[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
}

# #############################################
# Public IP for Azure Bastion
# #############################################

resource "azurerm_public_ip" "bastion" {
  name                = "${var.vnet_name}-bastion-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.etiquetas_comunes
}

# #############################################
# Azure Bastion Host
# Usa la subnet definida en terraform.tfvars (subnet_bastion)
# #############################################

resource "azurerm_bastion_host" "bastion" {
  name                = "${var.vnet_name}-bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.subnet["subnet_bastion"].id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  sku = "Basic" # SKU más básico

  tags = local.etiquetas_comunes
}
