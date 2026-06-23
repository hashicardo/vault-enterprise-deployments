#######################
#       Compute       #
#######################

# VM Image
data "aws_ami" "rhel" {
  most_recent = true

  filter {
    name   = "name"
    values = ["RHEL-9.7.0_HVM-*-arm64-0-Hourly2-GP3"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["309956199498"] # Red Hat
}

resource "aws_instance" "node" {
  for_each                    = var.vms_info
  ami                         = data.aws_ami.rhel.id
  instance_type               = var.vm_type
  subnet_id                   = aws_subnet.public.id
  private_ip                  = each.value.ip
  user_data                   = data.cloudinit_config.content[each.key].rendered
  user_data_replace_on_change = true
  key_name                    = aws_key_pair.simple_kp.key_name
  vpc_security_group_ids      = [aws_security_group.public.id]

  tags = {
    Name = "${var.prefix}-${each.value.id}"
  }
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "simple_kp" {
  key_name   = "${var.prefix}-keypair"
  public_key = tls_private_key.rsa.public_key_openssh
}

## Configuration:

data "cloudinit_config" "content" {
  for_each      = var.vms_info
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content = yamlencode({
      write_files = [
        #License and certs
        {
          path    = "/etc/vault.d/licence.hclic"
          content = var.vault_license
        },
        {
          path    = "/etc/vault.d/vault-ca.pem"
          content = acme_certificate.cert[each.key].issuer_pem
        },
        {
          path = "/etc/vault.d/vault-cert.pem"
          content = "${acme_certificate.cert[each.key].certificate_pem}${acme_certificate.cert[each.key].issuer_pem}" #needs full chain
        },
        {
          path    = "/etc/vault.d/vault-key.pem"
          content = nonsensitive(acme_certificate.cert[each.key].private_key_pem)
        }
      ]
    })
  }

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/boot.sh", {
      node_name   = each.value.id
      server_name = "${var.region}.${each.value.fqdn}"
      private_ip  = each.value.ip
    })
  }
}