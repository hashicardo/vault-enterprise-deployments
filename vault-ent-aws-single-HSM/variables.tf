#######################
#       General       #
#######################

variable "prefix" {
  type    = string
  default = "hashicardo"
}

# (passed as env var)
variable "vault_license" {
  type        = string
  description = "License string for Vault Enterprise"
}

variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "admin_password" {
  type        = string
  description = "Password for the admin user"
}

#######################
#      Networking     #
#######################

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block for the VPC"
}

variable "subnet_cidr" {
  type        = string
  default     = "10.0.0.0/24"
  description = "CIDR block for the primary subnet"
}

variable "allowed_cidrs" {
  type        = map(string)
  description = "IP addresses of external sources allowed to access the VPC."
  default = {
    office  = "80.24.36.153/32" #"46.26.36.56/32"
    private = "80.26.165.37/32"
  }
}

#######################
#       Compute       #
#######################

variable "vms_info" {
  type        = map(map(string))
  description = "A map containing information about the VMs to be created."
  default = {
    node0 = {
      id   = "vault0"
      ip   = "10.0.0.10"
      fqdn = "vault.riki.engineer"
    }
  }
}

variable "vm_type" {
  type        = string
  default     = "t4g.medium"
  description = "EC2 machine type"
}

#######################
#      TLS & DNS      #
#######################

variable "cloudflare_api_token" {
  type        = string
  description = "API token for Cloudflare for managing DNS records and ACME DNS challenges."
}

variable "tls_cert_email_address" {
  type        = string
  description = "Email for Let's Encrypt certificate."
}

variable "cloudflare_domain" {
  type        = string
  description = "Domain name to create records in."
  default     = "riki.engineer"
}