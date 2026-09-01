#! /bin/bash

set -euo pipefail

# This assumes certificates and license are already copied in the /etc/vault.d/ directory

LOGFILE="/var/log/vault/bootstrap.log"
VAULT_VERSION="2.0.4+ent.hsm"
SECRETS_DIR="/etc/vault/.secrets"

# The usual logging / error catching stuff
mkdir -p "$(dirname "$LOGFILE")"

function log {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local log_entry="$timestamp [$level] - $message"

  echo "$log_entry" | tee -a "$LOGFILE"
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

log "INFO" "Installing Dependencies"

## 1.1. Dependencies
apt update && apt install -y \
    unzip \
    wget \
    ca-certificates \
    softhsm2 \
    opensc \
    libengine-pkcs11-openssl \
    gnutls-bin \
&& rm -rf /var/lib/apt/lists/*

## 1.2. Install Vault:
log "INFO" "Installing Vault"

useradd --system --user-group --shell /bin/false vault
usermod -aG softhsm vault

wget https://releases.hashicorp.com/vault/$${VAULT_VERSION}/vault_$${VAULT_VERSION}_linux_arm64.zip && \
    unzip vault_$${VAULT_VERSION}_linux_arm64.zip  && \
    cp vault /usr/bin/vault && \
    rm vault_$${VAULT_VERSION}_linux_arm64.zip vault && \
    mkdir -p /etc/vault.d /var/lib/softhsm/tokens

# Test
vault version

## 1.2. Prepare files:
# Add new user and group: vault user already created when installing via apt

# Create necessary directories 
mkdir -p /etc/vault /var/lib/vault/data/raft
# This already comes with the vault installation with apt/apt but in case it didn't:
# mkdir /etc/vault.d

# Change ownership to the vault user 
chown -R vault:vault /etc/vault /var/lib/vault $(which vault)
chown vault:vault /var/lib/vault/data/raft

log "INFO" "Initializing HSM token"

softhsm2-util --init-token --free \
    --label "${token_label}" \
    --pin 1234 \
    --so-pin 0000

chown -R vault:vault /var/lib/softhsm/tokens

log "INFO" "Preparing Vault config files"

touch /etc/vault.d/vault.env

## 2.1. Vault config file
## Important considerations: This demo has both HSM integration. This needs to be included in the config
tee /etc/vault.d/config.hcl > /dev/null <<EOF
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

seal "pkcs11" {
  lib            = "/usr/lib/softhsm/libsofthsm2.so"
  token_label    = "${token_label}"
  pin            = "1234"
  key_label      = "vault-unseal-key"
  hmac_key_label = "vault-unseal-hmac-key"
  generate_key   = "true"
}

kms_library "pkcs11" {
  name    = "vault-hsm"
  library = "/usr/lib/softhsm/libsofthsm2.so"
}
EOF

## 2.2. Systemd service file
tee /etc/systemd/system/vault.service > /dev/null <<'EOF'
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
systemctl daemon-reload 
systemctl enable vault 
systemctl start vault


log "INFO" "Vault config complete. Service started"

# ----- INITIALIZE VAULT ---------------------------------------------------

mkdir -p "$${SECRETS_DIR}"

VAULT_ADDR="https://${server_name}:8200"
export VAULT_ADDR

INIT_OUTPUT_FILE="$${SECRETS_DIR}/vault-init.json"
ROOT_TOKEN_FILE="$${SECRETS_DIR}/vault-root-token.txt"
RECOVERY_KEY_FILE="$${SECRETS_DIR}/vault-recovery-key.txt"

# Wait for Vault to be responsive before attempting init
log "INFO" "Waiting for Vault API to respond..."
until curl -s -o /dev/null -w "%%{http_code}" "$${VAULT_ADDR}/v1/sys/health" | grep -qE "200|429|501|503"; do
  sleep 2
done

# Check if already initialized (idempotency)
INITIALIZED=$(curl -s "$${VAULT_ADDR}/v1/sys/health" | jq -r '.initialized')

if [ "$INITIALIZED" = "false" ]; then
  log "INFO" "Initializing Vault with 1 recovery key/threshold"

  vault operator init \
    -recovery-shares=1 \
    -recovery-threshold=1 \
    -format=json > "$${INIT_OUTPUT_FILE}"

  # Extract and store root token
  jq -r '.root_token' "$${INIT_OUTPUT_FILE}" > "$${ROOT_TOKEN_FILE}"

  # Extract and store the single recovery key
  jq -r '.recovery_keys_b64[0]' "$${INIT_OUTPUT_FILE}" > "$${RECOVERY_KEY_FILE}"

  chmod 600 "$${INIT_OUTPUT_FILE}" "$${ROOT_TOKEN_FILE}" "$${RECOVERY_KEY_FILE}"

  log "INFO" "Vault initialized. Root token and recovery key saved locally."
else
  log "INFO" "Vault already initialized, skipping."
fi

export VAULT_TOKEN=$(cat "$${ROOT_TOKEN_FILE}")

# ----- CREATE ADMIN USER -----------------------------------------------

log "INFO" "Creating admin user and policy"

# Superadmin policy
vault policy write admin - <<EOF
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF

# Userpass
vault auth enable userpass
vault write auth/userpass/users/admin password="${admin_password}" policies=admin

log "INFO" "Done!"
