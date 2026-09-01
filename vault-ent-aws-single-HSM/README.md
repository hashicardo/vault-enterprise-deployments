# Single node Vault running in EC2

## Export vars in ENV (safer):
```bash
export TF_VAR_cloudflare_api_token=
export TF_VAR_tls_cert_email_address=
export TF_VAR_vault_license=
```
And log in to your aws account with `aws`

# Secrets:
Currently configured to fetch them from 1P CLI:

After logging in to 1Password in the CLI:
```bash
export TF_VAR_cloudflare_api_token=$(op item get "Cloudflare API" --fields password --reveal)
export TF_VAR_vault_license=$(op item get "Vault Enterprise License" --vault "Personal" --fields "license key")
```
