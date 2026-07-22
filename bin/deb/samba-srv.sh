#!/usr/bin/env bash
set -euo pipefail

if [ ! -t 0 ]; then
    exec < /dev/tty 2>/dev/null || true
fi

echo "==> Configuring Samba File Host (Debian/Ubuntu)..."

declare -a MODIFIED_PATHS=()

SHARE_NAME="storage"
MNT_PATH="/mnt/${SHARE_NAME}"

echo "==> Installing Samba & UFW..."
sudo apt update && sudo apt install -y samba ufw
sudo mkdir -p "$MNT_PATH"
MODIFIED_PATHS+=("$MNT_PATH")

# Unprivileged LXC mapping check
read -r -p "Is this running inside an unprivileged Proxmox LXC? [y/N]: " IS_LXC
IS_LXC="${IS_LXC:-N}"

if [[ "$IS_LXC" =~ ^[Yy]$ ]]; then
    echo "==> Applying unprivileged LXC ID mapping (100000:100000)..."
    sudo chown -R 100000:100000 "$MNT_PATH"
    sudo chmod -R 775 "$MNT_PATH"
fi

# Configure Samba idempotently
if ! grep -q "\[${SHARE_NAME}\]" /etc/samba/smb.conf 2>/dev/null; then
    echo "==> Appending [${SHARE_NAME}] share configuration to /etc/samba/smb.conf..."
    sudo tee -a /etc/samba/smb.conf <<EOF > /dev/null

[${SHARE_NAME}]
   comment = Shared Storage SSD
   path = ${MNT_PATH}
   browseable = yes
   read only = no
   writable = yes
   guest ok = no
   create mask = 0775
   directory mask = 0775
   force user = root
EOF
    MODIFIED_PATHS+=("/etc/samba/smb.conf")
fi

echo "==> Enabling and starting smbd systemd service..."
sudo systemctl enable --now smbd

# Firewall Rules
echo "==> Permitting Samba traffic from 192.168.1.0/24 in UFW..."
sudo ufw allow from 192.168.1.0/24 to any app Samba

echo ""
echo "=========================================="
echo "==> Samba Server Provisioning Complete"
echo "=========================================="
echo "Modified or Created Paths:"
for path in "${MODIFIED_PATHS[@]}"; do
    echo "  - $path"
done
echo "Storage Path: ${MNT_PATH}"
