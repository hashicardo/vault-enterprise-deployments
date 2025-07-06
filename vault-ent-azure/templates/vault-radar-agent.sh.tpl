#! /bin/bash
set -euo pipefail

export VAULT_RADAR_VERSION=${vault_radar_version}
export OS_ARCH=${os_architecture}
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

function install_vault_radar_client {
    curl --remote-name https://releases.hashicorp.com/vault-radar/"$VAULT_RADAR_VERSION"/vault-radar_"$VAULT_RADAR_VERSION"_linux_"$OS_ARCH".zip
    unzip -o "vault-radar_"$VAULT_RADAR_VERSION"_linux_"$OS_ARCH".zip"
    sudo mv vault-radar /usr/bin/

    if ! vault-radar --version &>/dev/null; then
        log "ERROR" "Vault Radar client installation failed."
        exit 1
    else
        log "INFO" "Vault Radar client installed successfully."
    fi
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
    log "INFO" "Beginning custom_data script. Radar version: $VAULT_RADAR_VERSION, OS architecture: $OS_ARCH"
    log "INFO" "Installing dependencies."
    install_dependencies
    log "INFO" "Installing Vault Radar client."
    install_vault_radar_client

    exit_script 0
}

main "$@"