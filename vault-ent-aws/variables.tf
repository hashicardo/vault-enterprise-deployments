########################################
#                 VNET                 #
########################################
variable "prefix" {
  description = "Prefix for all resources."
  type        = string
  default     = "hashicardo"
}

variable "address_space" {
  description = "The address space that is used by the virtual network. You can supply more than one address space. Changing this forces a new resource to be created."
  default     = "10.0.0.0/16"
}

variable "location" {
  description = "The region where the virtual network is created."
  default     = "eastus"
}

variable "subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "10.0.0.0/24"
}

########################################
#               COMPUTE                #
########################################
variable "vm_size" {
  description = "Specifies the size of the virtual machine."
  default     = "Standard_D2s_v3"
}

variable "image_publisher" {
  description = "Name of the publisher of the image (az vm image list)"
  default     = "Canonical"
}

variable "image_offer" {
  description = "Name of the offer (az vm image list)"
  default     = "0001-com-ubuntu-server-jammy"
}

variable "image_sku" {
  description = "Image SKU to apply (az vm image list)"
  default     = "22_04-lts-gen2"
}

variable "image_version" {
  description = "Version of the image to apply (az vm image list)"
  default     = "latest"
}

variable "admin_username" {
  description = "Administrator user name for linux and mysql"
}

variable "admin_password" {
  description = "Administrator password for linux and mysql"
}

variable "number_of_nodes" {
  description = "Number of nodes in the vault cluster."
  type        = number
  default     = 3
}

########################################
#              DNS & TLS               #
########################################

variable "tls_cert_fqdn" {
  type        = string
  description = "Fully-qualified domain name (FQDN) of TLS certificate. This will be set as the Common Name of the certificate."
}

variable "tls_cert_email_address" {
  type        = string
  description = "Email address used for TLS certificate registration and recovery contact."
}

variable "cf_api_token" {
  type        = string
  description = "Cloudflare API token with permissions to manage DNS records for the domain used in the TLS certificate."
}

########################################
#             CREDENTIALS              #
########################################
variable "vault_license" {
  type        = string
  description = "Vault Enterprise license file content."
}

########################################
#           BASTION - RADAR            #
########################################
variable "vault_radar_version" {
  type        = string
  description = "Version of the Vault Radar agent to install on the bastion host."
  default     = "0.27.0"
}

variable "os_architecture" {
  type        = string
  description = "Operating system architecture for the Vault Radar agent (must be 'amd64' or 'arm64')."
  default     = "amd64"
  validation {
    condition     = contains(["amd64", "arm64"], var.os_architecture)
    error_message = "os_architecture must be either 'amd64' or 'arm64'."
  }
}

########################################
#             ENVIRONMENT              #
########################################
variable "environment" {
  description = "Environment for the deployment, e.g., 'dev', 'staging', 'prod'."
  type        = string
  default     = "dev"
}