data "cloudflare_zone" "r2" {
  filter = {
    name = var.cloudflare_domain
  }
}

resource "cloudflare_dns_record" "vault" {
  for_each = var.vms_info
  zone_id  = data.cloudflare_zone.r2.id
  name     = each.value.fqdn
  content  = aws_eip.public[each.key].public_ip
  type     = "A"
  ttl      = 3600
}