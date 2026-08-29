resource "azurerm_public_ip" "wazuh_pip" {
  name                = "pip-wazuh"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "wazuh_nic" {
  name                = "nic-wazuh"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.6"
    public_ip_address_id          = azurerm_public_ip.wazuh_pip.id
  }
}

resource "azurerm_linux_virtual_machine" "wazuh" {
  name                = "vm-wazuh"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s_v2"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.wazuh_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 50
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "wazuh_bootstrap" {
  name                       = "wazuh-bootstrap"
  virtual_machine_id         = azurerm_linux_virtual_machine.wazuh.id
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = "bash wazuh_bootstrap.sh"
  })

  protected_settings = jsonencode({
    fileUris           = [azurerm_storage_blob.wazuh_script.url]
    storageAccountName = azurerm_storage_account.scripts.name
    storageAccountKey  = azurerm_storage_account.scripts.primary_access_key
  })

  depends_on = [azurerm_storage_blob.wazuh_script]
}