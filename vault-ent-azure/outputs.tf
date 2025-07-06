output "vault-ip" {
  value = azurerm_public_ip.vault-pip.ip_address
}

output "bastion-ip" {
  value = azurerm_public_ip.bastion-pip.ip_address
}