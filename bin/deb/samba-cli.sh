#!/usr/bin/env bash
set -euo pipefail

if [ ! -t 0 ]; then
    exec < /dev/tty 2>/dev/null || true
fi

echo "==> Configuring CIFS Storage Mount Client (Debian/Ubuntu)..."

declare -a MODIFIED_PATHS=()

SMB_SERVER_IP="${1:-}"
SHARE_NAME="${2:-}"
MOUNT_POINT="${3:-}"

if [ -z "$SMB_SERVER_IP" ]; then
    read -r -p "Enter SMB Server IP [192.168.1.10]: " SMB_SERVER_IP
    SMB_SERVER_IP="${SMB_SERVER_IP:-192.168.1.10}"
fi

if [ -z "$SHARE_NAME" ]; then
    read -r -p "Enter Share Name [storage]: " SHARE_NAME
    SHARE_NAME="${SHARE_NAME:-storage}"
fi

if [ -z "$MOUNT_POINT" ]; then
    read -r -p "Enter Mount Point [/mnt/jar-01]: " MOUNT_POINT
    MOUNT_POINT="${MOUNT_POINT:-/mnt/jar-01}"
fi

read -r -p "Enter SMB Username [root]: " SMB_USER
SMB_USER="${SMB_USER:-root}"

read -r -s -p "Enter SMB Password: " SMB_PASS
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
