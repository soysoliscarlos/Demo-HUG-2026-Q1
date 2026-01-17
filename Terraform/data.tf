data "azurerm_client_config" "current" {}

data "azurerm_virtual_network" "vnet-vm" {
  name                = "Vnet-Jumpbox"
  resource_group_name = "RG-VM-Jumpbox"
}

