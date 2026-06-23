#! /bin/bash

set -euo pipefail

# This assumes certificates and license are already copied in the /etc/vault.d/ directory

# The usual logging / error catching stuff
LOGFILE="/var/log/bootstrap.log"

function log {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local log_entry="$timestamp [$level] - $message"

  echo "$log_entry" | sudo tee -a "$LOGFILE"
}

# This runs when ANY command fails
function on_error {
  local exit_code=$?
  local line_no=$1
  log "ERROR" "Script failed with exit code $exit_code at line $line_no"
}

trap 'on_error $LINENO' ERR

#######################
#        Start        #
#######################

log "INFO" "Installing Vault"

## 1.1. Download Vault Enterprise (RHEL)
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum install -y vault-enterprise
sudo yum update -y
# Test
vault version

## 1.2. Prepare files:
# Add new user and group: vault user already created when installing via yum

# Create necessary directories 
sudo mkdir -p /etc/vault /var/lib/vault/data/raft
# This already comes with the vault installation with yum/apt but in case it didn't:
# sudo mkdir /etc/vault.d

# Change ownership to the vault user 
sudo chown -R vault:vault /etc/vault /var/lib/vault $(which vault)
sudo chown vault:vault /var/lib/vault/data/raft

log "INFO" "Preparing Vault config files"


## 2.1. Vault config file
sudo tee /etc/vault.d/config.hcl > /dev/null <<EOF
# config.hcl for ${node_name}

api_addr      = "https://${server_name}:8200" 
cluster_addr  = "https://${server_name}:8201" 
ui            = true 
license_path  = "/etc/vault.d/licence.hclic" 
disable_mlock = true

listener "tcp" { 
  address            = "${private_ip}:8200" 
  cluster_address    = "${private_ip}:8201" 
  tls_client_ca_file = "/etc/vault.d/vault-ca.pem" 
  tls_cert_file      = "/etc/vault.d/vault-cert.pem" 
  tls_key_file       = "/etc/vault.d/vault-key.pem" 
}

storage "raft" { 
  path    = "/var/lib/vault/data" 
  node_id = "${node_name}" 
} 
EOF

## 2.2. Systemd service file
sudo tee /etc/systemd/system/vault.service > /dev/null <<'EOF'
[Unit] 
Description="HashiCorp Vault - A tool for managing secrets" 
Documentation=https://developer.hashicorp.com/vault/docs 
Requires=network-online.target 
After=network-online.target 
ConditionFileNotEmpty=/etc/vault.d/config.hcl 
StartLimitIntervalSec=60 
StartLimitBurst=3 

[Service] 
Type=notify 
EnvironmentFile=/etc/vault.d/vault.env 
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
ExecStart=/usr/bin/vault server -config=/etc/vault.d/config.hcl 
ExecReload=/bin/kill --signal HUP $MAINPID 
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

log "INFO" "Starting Vault service"
sudo systemctl daemon-reload 
sudo systemctl enable vault 
sudo systemctl start vault
