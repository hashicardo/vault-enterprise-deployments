#! /bin/bash
set -euo pipefail

INDEX="${index}"
FQDN="${fqdn}"
LICENSE="${license}"
CA_CERT="${vault_ca}"
CERT="${vault_cert}"
KEY="${vault_key}"
LOGFILE="/var/log/vault-cloud-init.log"

function log {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local log_entry="$timestamp [$level] - $message"

  echo "$log_entry" | tee -a "$LOGFILE"
}

function install_dependencies {
    # Install necessary packages
    sudo apt-get update
    sudo apt-get install -y unzip wget
}

function create_user {
    # Add new user and group
    sudo useradd --system --user-group --shell /bin/false vault

    # Create necessary directories
    sudo mkdir -p /etc/vault /var/lib/vault/data/raft
    sudo mkdir /etc/vault.d

    # Change ownership to the vault user
    sudo chown -R vault:vault /etc/vault /var/lib/vault
    sudo chown vault:vault /var/lib/vault/data/raft
}

function download_vault {
    # Download Vault Ent release:
    wget https://releases.hashicorp.com/vault/1.19.0+ent/vault_1.19.0+ent_linux_amd64.zip

    # Unzip it
    unzip vault_1.19.0+ent_linux_amd64.zip

    # Move to somewhere in the path. E.g. /usr/local/bin/:
    sudo mv vault /usr/local/bin/

    # Change ownership too:
    sudo chown vault:vault /usr/local/bin/vault
}

function create_creds_files {
    # Create Vault full chain certificate file: both CERT and CA
    echo "$CERT$CA_CERT" | sudo tee /etc/vault.d/vault-chain.pem > /home/hashicardo/vault-chain.pem

    # Create Vault CA certificate file
    echo "$CA_CERT" | sudo tee /etc/vault.d/vault-ca.pem > /home/hashicardo/vault-ca.pem

    # Create Vault certificate file
    echo "$CERT" | sudo tee /etc/vault.d/vault-cert.pem > /home/hashicardo//vault-cert.pem

    # Create Vault key file
    echo "$KEY" | sudo tee /etc/vault.d/vault-key.pem > /home/hashicardo//vault-key.pem

    # Create Vault license file
    echo "$LICENSE" | sudo tee /etc/vault.d/licence.hclic > /dev/null

    # Set permissions for the files
    sudo chown vault:vault /etc/vault.d/*
    sudo chmod 640 /etc/vault.d/*
}

function configure_vault {
    # Create Vault configuration file
    sudo bash -c "cat > /etc/vault.d/config.hcl" <<EOF

# config.hcl for Vault$INDEX (voter mode example)

api_addr      = "https://10.0.0.1$INDEX:8200"
cluster_addr  = "https://10.0.0.1$INDEX:8201"
disable_mlock = true    #for raft
ui            = true
license_path  = "/etc/vault.d/licence.hclic"

listener "tcp" {
    address            = "10.0.0.1$INDEX:8200"
    cluster_address    = "10.0.0.1$INDEX:8201"
    tls_cert_file      = "/etc/vault.d/vault-chain.pem"
    tls_key_file       = "/etc/vault.d/vault-key.pem"
}

storage "raft" {
    path    = "/var/lib/vault/data"
    node_id = "vault$INDEX"

    retry_join {
        leader_api_addr         = "https://10.0.0.11:8200"
        leader_ca_cert_file     = "/etc/vault.d/vault-ca.pem"
        leader_client_cert_file = "/etc/vault.d/vault-cert.pem"
        leader_client_key_file  = "/etc/vault.d/vault-key.pem"
        leader_tls_servername   = "$FQDN"
    }

retry_join {
        leader_api_addr         = "https://10.0.0.12:8200"
        leader_ca_cert_file     = "/etc/vault.d/vault-ca.pem"
        leader_client_cert_file = "/etc/vault.d/vault-cert.pem"
        leader_client_key_file  = "/etc/vault.d/vault-key.pem"
        leader_tls_servername   = "$FQDN"
    }

retry_join {
        leader_api_addr         = "https://10.0.0.13:8200"
        leader_ca_cert_file     = "/etc/vault.d/vault-ca.pem"
        leader_client_cert_file = "/etc/vault.d/vault-cert.pem"
        leader_client_key_file  = "/etc/vault.d/vault-key.pem"
        leader_tls_servername   = "$FQDN"
    }
}

telemetry {
    disable_hostname         = true
    prometheus_retention_time = "12h"
}

EOF

}

function gen_systemd {
    local kill_cmd=$(which kill)
    sudo cat << EOF >> /etc/systemd/system/vault.service
[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://developer.hashicorp.com/vault/docs
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/config.hcl
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/config.hcl
ExecReload=$${kill_cmd} --signal HUP \$MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
LimitNOFILE=65536
LimitMEMLOCK=infinity
LimitCORE=0

[Install]
WantedBy=multi-user.target
EOF
}

function start_enable_vault {
  sudo systemctl daemon-reload
  sudo systemctl enable vault
  sudo systemctl start vault
}

exit_script() {
  if [[ "$1" == 0 ]]; then
    log "INFO" "Vault custom_data script finished successfully!"
  else
    log "ERROR" "Vault custom_data script finished with error code $1."
  fi

  exit "$1"
}

main() {
    log "INFO" "Beginning custom_data script."
    log "INFO" "Installing dependencies."
    install_dependencies
    log "INFO" "Creating vault user and directories."
    create_user
    log "INFO" "Downloading Vault Ent."
    download_vault
    log "INFO" "Creating credentials files."
    create_creds_files
    log "INFO" "Configuring Vault."
    configure_vault
    log "INFO" "Generating systemd service file."
    gen_systemd
    log "INFO" "Starting and enabling Vault service."
    start_enable_vault
    log "INFO" "Custom data script completed successfully."

    exit_script 0
}

main "$@"