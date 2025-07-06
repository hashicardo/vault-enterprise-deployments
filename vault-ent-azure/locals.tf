locals {
  node_ips = {
    "1" = "10.0.0.11",
    "2" = "10.0.0.12",
    "3" = "10.0.0.13"
  }

  custom_data_args = {
    fqdn       = var.tls_cert_fqdn
    license    = var.vault_license
    vault_ca   = acme_certificate.certificate.issuer_pem
    vault_cert = acme_certificate.certificate.certificate_pem
    vault_key  = nonsensitive(acme_certificate.certificate.private_key_pem)
  }
}