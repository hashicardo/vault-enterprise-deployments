output "key" {
  value     = tls_private_key.rsa.private_key_pem
  sensitive = true
}

output "public_ips" {
  value = { for k, v in aws_eip.public : k => v.public_ip }
}

output "server_names" {
  value = { for k, v in var.vms_info : k => v.fqdn }
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_id" {
  value = aws_subnet.public.id
}

output "sg_id" {
  value = aws_security_group.public.id
}