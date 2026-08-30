resource "azurerm_public_ip" "client_pip" {
  name                = "pip-client"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "client_nic" {
  name                = "nic-client"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

   

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.5"
    public_ip_address_id          = azurerm_public_ip.client_pip.id
  }
}

resource "azurerm_windows_virtual_machine" "client" {
  name                = "vm-client"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2s_v3"
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.client_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-24h2-pro"
    version   = "latest"
  }
}


resource "azurerm_virtual_machine_extension" "client_winrm" {
  name                       = "winrm-bootstrap"
  virtual_machine_id         = azurerm_windows_virtual_machine.client.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -File winrm_bootstrap.ps1"
    scriptHash       = filemd5("${path.module}/winrm_bootstrap.ps1")
  })

  protected_settings = jsonencode({
    fileUris           = [azurerm_storage_blob.winrm_script.url]
    storageAccountName = azurerm_storage_account.scripts.name
    storageAccountKey  = azurerm_storage_account.scripts.primary_access_key
  })

  depends_on = [azurerm_storage_blob.winrm_script]
}