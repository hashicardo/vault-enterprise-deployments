#######################
#      Public IP      #
#######################
resource "azurerm_public_ip" "vault-pip" {
  name                = "${var.prefix}-vault-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.vault.name
  allocation_method   = "Static"
  domain_name_label   = "vault-${var.prefix}"
}

#######################
#    Load Balancer    #
#######################

resource "azurerm_lb" "vault_lb" {
  name                = "${var.prefix}-vault-lb"
  location            = var.location
  resource_group_name = azurerm_resource_group.vault.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "vaultFrontEnd"
    public_ip_address_id = azurerm_public_ip.vault-pip.id
  }
}

resource "azurerm_lb_probe" "vault_probe" {
  name                = "vaultHealthProbe"
  loadbalancer_id     = azurerm_lb.vault_lb.id
  protocol            = "Https"
  port                = 8200
  request_path        = "/v1/sys/health?perfstandbyok=1&uninitcode=200"
  interval_in_seconds = 15
}

resource "azurerm_lb_rule" "vault_lb_rule" {
  name                           = "vaultTCPRule"
  loadbalancer_id                = azurerm_lb.vault_lb.id
  protocol                       = "Tcp"
  frontend_port                  = 8200
  backend_port                   = 8200
  frontend_ip_configuration_name = "vaultFrontEnd"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.vault_backend_pool.id]
  probe_id                       = azurerm_lb_probe.vault_probe.id
}

resource "azurerm_lb_backend_address_pool" "vault_backend_pool" {
  name            = "vaultBackEndPool"
  loadbalancer_id = azurerm_lb.vault_lb.id
}

resource "azurerm_lb_backend_address_pool_address" "node" {
  for_each = local.node_ips

  name                    = "vault-${each.key}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.vault_backend_pool.id
  virtual_network_id      = azurerm_virtual_network.vnet.id
  ip_address              = each.value
}
