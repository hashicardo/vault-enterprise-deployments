# Vault Enterprise resources

This repo contains a bunch of resources related to Vault.

The folders [vault-ent-azure](./vault-ent-azure/) and [vault-ent-aws](./vault-ent-aws/) contain basic, bare-bones configurations in Terraform to deploy Vault Enterprise in Azure and AWS respectively.

These configurations are based on the HVD modules but simplified for easier deployment and management. Of course, the the simplicity comes with several tradeoffs:

- No autoscaling: the module deploys a specific number of VMs which can be modified with the variable `number_of_nodes`. Note: for now the configuration templates are kind of 'hard coded' to be only 3 machines so you'll likely encounter issues if you specify a different number.
- Ubuntu: the OS is fixed to Ubuntu Jammy 22.04. This can be changed by modifying the variables `image_offer`, `image_sku`, `image_version`
- Manual unseal: part of the motivation behind creating these modules was to practice some of the concepts of Vault, for example manually unsealing and joining nodes to a raft backend. No auto-unseal but guaranteed fun.
- [!IMPORTANT] TLS: at the moment, the provisioning of TLS certificates is automated using the ACME provider with the DNS challenge configured to use Cloudflare (my personal preference). If you have a different DNS provider or an active zone in AzureDNS / AWS Route53 please change the configuration in [tls.tf](./vault-ent-azure/tls.tf)

As a random plus, the bastion server has the Vault Radar Agent CLI installed locally. Learn more [here](https://developer.hashicorp.com/hcp/docs/vault-radar/cli).

>[!NOTE]
> The AWS module is a work in progress. It's almost empty at the time of this writing.
