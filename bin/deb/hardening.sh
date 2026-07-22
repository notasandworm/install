#!/usr/bin/env bash
set -euo pipefail

get_local_ip() {
    ip -4 route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || hostname -I 2>/dev/null | awk '{print $1}' || echo ""
}

get_tailscale_ip() {
    if command -v tailscale &>/dev/null; then
        tailscale ip -4 2>/dev/null || echo ""
    else
        echo ""
    fi
}

echo "==> Hardening Server Baseline Security (Debian/Ubuntu)..."

declare -a MODIFIED_PATHS=()

# 1. Install Security Suite
echo "==> Installing ufw, openssh-server, unattended-upgrades, fail2ban..."
sudo apt update && sudo apt install -y ufw openssh-server unattended-upgrades fail2ban
MODIFIED_PATHS+=("/etc/fail2ban/fail2ban.conf")
MODIFIED_PATHS+=("/etc/apt/apt.conf.d/20auto-upgrades")

# 2. UFW Rules Setup
echo "==> Configuring UFW firewall posture..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow in from 192.168.1.0/24 to any port 22 proto tcp
sudo ufw --force enable
MODIFIED_PATHS+=("/etc/ufw/user.rules")

# 3. SSH Permissions Posture
echo "==> Hardening SSH permissions posture..."
chmod 755 ~
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
chown -R "$USER:$USER" ~/.ssh
MODIFIED_PATHS+=("$HOME/.ssh permissions")

LOCAL_IP="$(get_local_ip)"
TS_IP="$(get_tailscale_ip)"

echo ""
echo "=========================================="
echo "==> Server Hardening Complete"
echo "=========================================="
echo "Installed Packages & Tools:"
echo "  - Security Suite: ufw, openssh-server, unattended-upgrades, fail2ban"
echo ""
echo "Modified or Created Paths:"
for path in "${MODIFIED_PATHS[@]}"; do
    echo "  - $path"
done

# NOTE FOR DEVELOPERS: Add post-installation action/service activation instructions below
# for any packages or services that require manual user setup (e.g. 'sudo tailscale up',
# 'sudo dpkg-reconfigure --priority=low unattended-upgrades', etc.).
echo ""
echo "Post-Install Action Required:"
echo "  * Add your public SSH key to: ~/.ssh/authorized_keys"
echo "  * (Optional) Edit SSH server config to harden authentication:"
echo "      sudo nano /etc/ssh/sshd_config"
echo "  * To configure automatic unattended-upgrades priority settings, run:"
echo "      sudo dpkg-reconfigure --priority=low unattended-upgrades"

echo ""
echo "SSH Connection Verification & Network IPs:"
if [ -n "$LOCAL_IP" ]; then
    echo "  * Local LAN SSH:       ssh ${USER}@${LOCAL_IP}"
else
    echo "  * Local LAN SSH:       ssh ${USER}@<your-local-lan-ip>"
fi

if [ -n "$TS_IP" ]; then
    echo "  * Tailscale SSH:       ssh ${USER}@${TS_IP}"
elif command -v tailscale &>/dev/null; then
    echo "  * Tailscale SSH:       Run 'sudo tailscale up' first to obtain Tailscale IP"
fi


