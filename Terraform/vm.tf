# #############################################
# Network Interface for VM
# #############################################

resource "azurerm_network_interface" "vm" {
  name                = "${var.vnet_name}-vm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet["subnet_vm"].id # Usa la subnet definida en terraform.tfvars
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.etiquetas_comunes
}

# #############################################
# Windows Server Virtual Machine with Azure AD Login
# #############################################

resource "azurerm_windows_virtual_machine" "vm" {
  name                = "${var.vnet_name}-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B2s"                           # 2 vCPU, 4 GB RAM
  admin_username      = "azureuser"                              # No se usa con Azure AD, pero es requerido
  admin_password      = random_password.vm_admin_password.result # Contraseña generada aleatoriamente

  network_interface_ids = [
    azurerm_network_interface.vm.id,
  ]

  # Identity para Azure AD login
  identity {
    type = "SystemAssigned"
  }

  os_disk {
    name                 = "${var.vnet_name}-vm-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  tags = local.etiquetas_comunes
}

# #############################################
# Azure AD Login Extension for Windows
# #############################################

resource "azurerm_virtual_machine_extension" "aad_login" {
  name                 = "AADLoginForWindows"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADLoginForWindows"
  type_handler_version = "2.2"

  tags = local.etiquetas_comunes
}

# #############################################
# Role Assignment - Virtual Machine User Login
# Asigna el grupo de Azure AD para autenticación
# #############################################

resource "azurerm_role_assignment" "vm_user_login" {
  scope                = azurerm_windows_virtual_machine.vm.id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = var.vm_azure_ad_group_object_id
}

# #############################################
# Role Assignment - Virtual Machine Administrator Login (Opcional)
# Descomentar si el grupo también necesita permisos de administrador
# #############################################

# resource "azurerm_role_assignment" "vm_admin_login" {
#   scope                = azurerm_windows_virtual_machine.vm.id
#   role_definition_name = "Virtual Machine Administrator Login"
#   principal_id         = var.vm_azure_ad_group_object_id
# }
