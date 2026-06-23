#------------------------------------------------------------------------------
# TLS private key
#------------------------------------------------------------------------------
resource "tls_private_key" "cert" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

#------------------------------------------------------------------------------
# ACME registration and certificate
#------------------------------------------------------------------------------
resource "acme_registration" "cert" {
  account_key_pem = tls_private_key.cert.private_key_pem
  email_address   = var.tls_cert_email_address
}

resource "acme_certificate" "cert" {
  for_each        = var.vms_info
  account_key_pem = acme_registration.cert.account_key_pem
  common_name     = each.value.fqdn
  # subject_alternative_names = var.sans
  pre_check_delay = 20

  dns_challenge {
    provider = "cloudflare"

    config = {
      CF_DNS_API_TOKEN = var.cloudflare_api_token
    }
  }
}
