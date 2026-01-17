# #############################################
# VNet Peering between local VNet and existing VNet
# #############################################

resource "azurerm_virtual_network_peering" "vnet_to_vnet_vm" {
  name                      = "${azurerm_virtual_network.vnet.name}-to-${data.azurerm_virtual_network.vnet-vm.name}"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet.name
  remote_virtual_network_id = data.azurerm_virtual_network.vnet-vm.id

  # Ensure traffic can flow between VNets
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "vnet_vm_to_vnet" {
  name                      = "${data.azurerm_virtual_network.vnet-vm.name}-to-${azurerm_virtual_network.vnet.name}"
  resource_group_name       = data.azurerm_virtual_network.vnet-vm.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.vnet-vm.name
  remote_virtual_network_id = azurerm_virtual_network.vnet.id

  # Ensure traffic can flow between VNets
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
