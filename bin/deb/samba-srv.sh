#!/usr/bin/env bash
set -euo pipefail

prompt_read() {
    local prompt_text="$1"
    local target_var="$2"
    local default_val="${3:-}"
    local input_val=""

    if [ -c /dev/tty ]; then
        read -r -p "$prompt_text" input_val < /dev/tty || input_val="$default_val"
    else
        input_val="$default_val"
    fi
    eval "$target_var=\"\${input_val:-\$default_val}\""
}

echo "==> Configuring Samba File Host (Debian/Ubuntu)..."

declare -a MODIFIED_PATHS=()

SHARE_NAME="storage"
MNT_PATH="/mnt/${SHARE_NAME}"

echo "==> Installing Samba & UFW..."
sudo apt update && sudo apt install -y samba ufw
sudo mkdir -p "$MNT_PATH"
MODIFIED_PATHS+=("$MNT_PATH")

# Unprivileged LXC mapping check
prompt_read "Is this running inside an unprivileged Proxmox LXC? [y/N]: " IS_LXC "N"

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
echo "Installed Packages & Tools:"
echo "  - File Server Suite: samba, ufw"
echo ""
echo "Storage Path: ${MNT_PATH}"
echo "Modified or Created Paths:"
for path in "${MODIFIED_PATHS[@]}"; do
    echo "  - $path"
done

# NOTE FOR DEVELOPERS: Add post-installation action/service activation instructions below
# for any packages or services that require manual user setup (e.g. 'sudo tailscale up',
# 'sudo dpkg-reconfigure --priority=low unattended-upgrades', etc.).
echo ""
echo "Post-Install Action Required:"
echo "  * Add a Samba user password for authentication by running:"
echo "      sudo smbpasswd -a \$USER"

