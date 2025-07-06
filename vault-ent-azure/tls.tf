resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "registration" {
  account_key_pem = tls_private_key.private_key.private_key_pem
  email_address   = var.tls_cert_email_address
}

resource "acme_certificate" "certificate" {
  account_key_pem = acme_registration.registration.account_key_pem
  common_name     = var.tls_cert_fqdn
  # subject_alternative_names = ["*.${local.domain}"] # To have wildcard

  dns_challenge {
    provider = "cloudflare"

    config = {
      CF_DNS_API_TOKEN = var.cf_api_token
    }
  }

  depends_on = [acme_registration.registration]
}

