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
declare -a APT_MANAGED_TOOLS=()

# 1. Security Suite Checklist
SEC_TOOLS=(ufw openssh-server unattended-upgrades fail2ban tailscale vsec)
SELECTED_SEC_TOOLS=()

echo "Security suite tools & services:"
echo "  ${SEC_TOOLS[*]}"
prompt_read "Install all security baseline tools? [Y/n]: " INSTALL_SEC_RESP "Y"

if [[ "$INSTALL_SEC_RESP" =~ ^[Yy]$ ]]; then
    SELECTED_SEC_TOOLS=("${SEC_TOOLS[@]}")
else
    for tool in "${SEC_TOOLS[@]}"; do
        prompt_read "  Install $tool? [Y/n]: " TOOL_RESP "Y"
        if [[ "$TOOL_RESP" =~ ^[Yy]$ ]]; then
            SELECTED_SEC_TOOLS+=("$tool")
        fi
    done
fi

is_sec_selected() {
    local target="$1"
    for t in "${SELECTED_SEC_TOOLS[@]}"; do
        [ "$t" = "$target" ] && return 0
    done
    return 1
}

# 2. SSH Port Prompt
SSH_PORT="22"
if is_sec_selected "ufw" || is_sec_selected "openssh-server"; then
    prompt_read "Enter SSH Port [22]: " SSH_PORT "22"
fi

# 3. Base APT Installation for Selected Standard Security Packages
APT_SEC_PKGS=()
for pkg in ufw openssh-server unattended-upgrades fail2ban; do
    if is_sec_selected "$pkg"; then
        APT_SEC_PKGS+=("$pkg")
    fi
done

if [ ${#APT_SEC_PKGS[@]} -gt 0 ]; then
    echo "==> Installing selected security APT packages..."
    sudo apt update && sudo apt install -y "${APT_SEC_PKGS[@]}"
fi

if is_sec_selected "fail2ban"; then
    MODIFIED_PATHS+=("/etc/fail2ban/fail2ban.conf")
fi

if is_sec_selected "unattended-upgrades"; then
    MODIFIED_PATHS+=("/etc/apt/apt.conf.d/20auto-upgrades")
fi

# 4. Tailscale Installation (Mesh VPN)
if is_sec_selected "tailscale" && ! command -v tailscale &>/dev/null; then
    echo "==> Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    MODIFIED_PATHS+=("/usr/bin/tailscale")
    APT_MANAGED_TOOLS+=("Tailscale")
fi

# 5. vsec Installation (Server Security Dashboard CLI)
if is_sec_selected "vsec" && ! command -v vsec &>/dev/null; then
    echo "==> Installing vsec..."
    sudo curl -fsSL https://raw.githubusercontent.com/notasandworm/vsec/main/vsec -o /usr/local/bin/vsec && sudo chmod +x /usr/local/bin/vsec
    MODIFIED_PATHS+=("/usr/local/bin/vsec")
fi

# 5. UFW Rules & Firewall Posture Setup
if is_sec_selected "ufw"; then
    echo "==> Configuring UFW firewall posture..."
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow SSH on configured port from local LAN
    sudo ufw allow in from 192.168.1.0/24 to any port "${SSH_PORT}" proto tcp
    
    if is_sec_selected "tailscale" || command -v tailscale &>/dev/null; then
        sudo ufw allow in on tailscale0 to any port "${SSH_PORT}" proto tcp 2>/dev/null || true
    fi

    sudo ufw --force enable
    MODIFIED_PATHS+=("/etc/ufw/user.rules")
fi

# 6. SSH Permissions & Custom Port Posture Setup
if is_sec_selected "openssh-server"; then
    echo "==> Hardening SSH permissions posture..."
    chmod 755 ~
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    touch ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    chown -R "$USER:$USER" ~/.ssh
    MODIFIED_PATHS+=("$HOME/.ssh permissions")

    if [ "$SSH_PORT" != "22" ]; then
        echo "==> Setting custom SSH port (${SSH_PORT}) in /etc/ssh/sshd_config.d/custom-port.conf..."
        sudo mkdir -p /etc/ssh/sshd_config.d
        echo "Port ${SSH_PORT}" | sudo tee /etc/ssh/sshd_config.d/custom-port.conf > /dev/null
        MODIFIED_PATHS+=("/etc/ssh/sshd_config.d/custom-port.conf")
        sudo systemctl restart ssh 2>/dev/null || sudo systemctl restart sshd 2>/dev/null || true
    fi
fi

LOCAL_IP="$(get_local_ip)"
TS_IP="$(get_tailscale_ip)"

# 7. Execution Summary & Review Block
echo ""
echo "=========================================="
echo "==> Server Hardening Complete"
echo "=========================================="
echo "Installed Packages & Tools:"
if [ ${#SELECTED_SEC_TOOLS[@]} -gt 0 ]; then
    echo "  - Security Suite: ${SELECTED_SEC_TOOLS[*]}"
else
    echo "  - None selected"
fi

echo ""
echo "Modified or Created Paths:"
for path in "${MODIFIED_PATHS[@]}"; do
    echo "  - $path"
done

if [ ${#APT_MANAGED_TOOLS[@]} -gt 0 ]; then
    echo ""
    echo "Package Update Notice:"
    echo "  The following tools were installed via custom APT repositories:"
    for tool in "${APT_MANAGED_TOOLS[@]}"; do
        echo "    * $tool"
    done
    echo "  To update these tools in the future, simply run: sudo apt update && sudo apt upgrade"
fi

# NOTE FOR DEVELOPERS: Add post-installation action/service activation instructions below
# for any packages or services that require manual user setup (e.g. 'sudo tailscale up',
# 'sudo dpkg-reconfigure --priority=low unattended-upgrades', etc.).
echo ""
echo "Post-Install Action Required:"
if [ "$SSH_PORT" != "22" ]; then
    echo "  * Custom SSH Port configured: ${SSH_PORT} (Set in /etc/ssh/sshd_config.d/custom-port.conf)"
fi

if is_sec_selected "tailscale"; then
    echo "  * Tailscale installed! To authenticate and connect to your mesh network, run:"
    echo "      sudo tailscale up"
fi

if is_sec_selected "openssh-server"; then
    echo "  * Add your public SSH key to: ~/.ssh/authorized_keys"
    echo "  * (Optional) Edit SSH server config to harden authentication:"
    echo "      sudo nano /etc/ssh/sshd_config"
fi

if is_sec_selected "unattended-upgrades"; then
    echo "  * To configure automatic unattended-upgrades priority settings, run:"
    echo "      sudo dpkg-reconfigure --priority=low unattended-upgrades"
fi

if is_sec_selected "vsec" || command -v vsec &>/dev/null; then
    echo "  * To view your server security dashboard, run:"
    echo "      sudo vsec"
fi

SSH_OPT=""
if [ "$SSH_PORT" != "22" ]; then
    SSH_OPT="-p ${SSH_PORT} "
fi

echo ""
echo "SSH Connection Verification & Network IPs:"
if [ -n "$LOCAL_IP" ]; then
    echo "  * Local LAN SSH:       ssh ${SSH_OPT}${USER}@${LOCAL_IP}"
else
    echo "  * Local LAN SSH:       ssh ${SSH_OPT}${USER}@<your-local-lan-ip>"
fi

if [ -n "$TS_IP" ]; then
    echo "  * Tailscale SSH:       ssh ${SSH_OPT}${USER}@${TS_IP}"
elif is_sec_selected "tailscale" || command -v tailscale &>/dev/null; then
    echo "  * Tailscale SSH:       Run 'sudo tailscale up' first to obtain Tailscale IP"
fi
