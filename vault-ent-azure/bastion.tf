#######################
#      Public IP      #
#######################
resource "azurerm_public_ip" "bastion-pip" {
  name                = "${var.prefix}-bastion-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.vault.name
  allocation_method   = "Static"
  domain_name_label   = "bastion-${var.prefix}"
}

#######################
# Network interfaces  #
#######################
resource "azurerm_network_interface" "bastion-nic" {
  name                = "${var.prefix}-bastion-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.vault.name

  ip_configuration {
    name                          = "${var.prefix}-ipconfig-bastion"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.0.10"
    public_ip_address_id          = azurerm_public_ip.bastion-pip.id
  }
}
# Linux nic
resource "azurerm_network_interface_security_group_association" "nic-association-bastion" {
  network_interface_id      = azurerm_network_interface.bastion-nic.id
  network_security_group_id = azurerm_network_security_group.linux.id
}

#######################
#         VMs         #
#######################

# VM1 - linux:
resource "azurerm_linux_virtual_machine" "bastion" {
  name                            = "${var.prefix}-bastion"
  location                        = var.location
  resource_group_name             = azurerm_resource_group.vault.name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.bastion-nic.id]

  custom_data = base64encode(
    templatefile(
      "${path.module}/templates/vault-radar-agent.sh.tpl",
      {
        "vault_radar_version" = var.vault_radar_version,
        "os_architecture"     = var.os_architecture,
      }
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
  depends_on = [azurerm_network_interface_security_group_association.nic-association-bastion]
}

