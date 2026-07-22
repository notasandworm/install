#!/usr/bin/env bash
set -euo pipefail

prompt_read() {
    local prompt_text="$1"
    local target_var="$2"
    local default_val="${3:-}"
    local is_silent="${4:-false}"
    local input_val=""
    local read_flags="-r"

    if [ "$is_silent" = "true" ]; then
        read_flags="-rs"
    fi

    if [ -c /dev/tty ]; then
        read $read_flags -p "$prompt_text" input_val < /dev/tty || input_val="$default_val"
    else
        input_val="$default_val"
    fi
    eval "$target_var=\"\${input_val:-\$default_val}\""
}

echo "==> Configuring CIFS Storage Mount Client (Debian/Ubuntu)..."

declare -a MODIFIED_PATHS=()

SMB_SERVER_IP="${1:-}"
SHARE_NAME="${2:-}"
MOUNT_POINT="${3:-}"

if [ -z "$SMB_SERVER_IP" ]; then
    prompt_read "Enter SMB Server IP [192.168.1.10]: " SMB_SERVER_IP "192.168.1.10"
fi

if [ -z "$SHARE_NAME" ]; then
    prompt_read "Enter Share Name [storage]: " SHARE_NAME "storage"
fi

if [ -z "$MOUNT_POINT" ]; then
    prompt_read "Enter Mount Point [/mnt/jar-01]: " MOUNT_POINT "/mnt/jar-01"
fi

prompt_read "Enter SMB Username [root]: " SMB_USER "root"
prompt_read "Enter SMB Password: " SMB_PASS "" "true"
echo

echo "==> Installing cifs-utils..."
sudo apt update && sudo apt install -y cifs-utils

if [ ! -d "$MOUNT_POINT" ]; then
    sudo mkdir -p "$MOUNT_POINT"
    MODIFIED_PATHS+=("$MOUNT_POINT (directory created)")
fi

CRED_FILE="/etc/cifs-credentials"
echo "username=${SMB_USER}" | sudo tee "$CRED_FILE" > /dev/null
echo "password=${SMB_PASS}" | sudo tee -a "$CRED_FILE" > /dev/null
sudo chmod 600 "$CRED_FILE"
sudo chown root:root "$CRED_FILE"
MODIFIED_PATHS+=("$CRED_FILE")

FSTAB_ENTRY="//${SMB_SERVER_IP}/${SHARE_NAME} ${MOUNT_POINT} cifs credentials=${CRED_FILE},_netdev,x-systemd.automount 0 0"

if ! grep -q "$MOUNT_POINT" /etc/fstab; then
    echo "==> Adding auto-mount entry to /etc/fstab..."
    echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab > /dev/null
    sudo systemctl daemon-reload
    sudo mount -a || echo "Warning: mount -a failed; verify credentials and network availability."
    MODIFIED_PATHS+=("/etc/fstab")
fi

echo ""
echo "=========================================="
echo "==> Samba Client Configuration Complete"
echo "=========================================="
echo "Mount Target: //${SMB_SERVER_IP}/${SHARE_NAME} -> ${MOUNT_POINT}"
echo "Modified or Created Paths:"
for path in "${MODIFIED_PATHS[@]}"; do
    echo "  - $path"
done
