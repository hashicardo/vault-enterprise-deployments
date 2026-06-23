terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.30.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~>5.16.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "~>2.40"
    }
  }
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory" # prod - for your real certs
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      "Env"     = "Demo"
      "Project" = "Vault Enterprise"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}