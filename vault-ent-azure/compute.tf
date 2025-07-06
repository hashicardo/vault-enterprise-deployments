#######################
# Network interfaces  #
#######################
resource "azurerm_network_interface" "linux-nic" {
  # As many nics as ips:
  for_each = local.node_ips

  name                = "${var.prefix}-linux${each.key}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.vault.name

  ip_configuration {
    name                          = "${var.prefix}-ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value
    #NO public ip
  }
}
# Linux nic
resource "azurerm_network_interface_security_group_association" "nic-association-linux" {
  for_each                  = azurerm_network_interface.linux-nic
  network_interface_id      = each.value.id
  network_security_group_id = azurerm_network_security_group.linux.id
}

#######################
#         VMs         #
#######################

# VM1 - linux:
resource "azurerm_linux_virtual_machine" "linux" {
  # as many VMs as nics:
  for_each = azurerm_network_interface.linux-nic

  name                            = "${var.prefix}-linux-${each.key}"
  location                        = var.location
  resource_group_name             = azurerm_resource_group.vault.name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [each.value.id]

  custom_data = base64encode(
    templatefile(
      "${path.module}/templates/custom_data.sh.tpl",
      merge(local.custom_data_args, { "index" = "${each.key}" })
    )
  )

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = "64"
  }

  tags = {}

  # Added to allow destroy to work correctly.
  depends_on = [azurerm_network_interface_security_group_association.nic-association-linux]
}