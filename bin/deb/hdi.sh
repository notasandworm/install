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

install_ydotool() {
    if command -v ydotool &>/dev/null; then
        return 0
    fi

    echo "==> Checking ydotool availability..."
    if sudo apt install -y ydotool 2>/dev/null; then
        MODIFIED_PATHS+=("/usr/bin/ydotool")
        return 0
    fi

    echo ""
    echo "⚠️  Notice: 'ydotool' is not in default Debian main. It is available via official 'trixie-backports'."
    prompt_read "I understand the risks of potential library dependency conflicts, untested software interactions, and slower security patching (worth it for this use case!) [y/N]: " ACK_RISK_RESP "N"

    if [[ "$ACK_RISK_RESP" =~ ^[Yy]$ ]]; then
        if [ ! -f /etc/apt/sources.list.d/trixie-backports.list ]; then
            echo "deb http://deb.debian.org/debian trixie-backports main" | sudo tee /etc/apt/sources.list.d/trixie-backports.list > /dev/null
            MODIFIED_PATHS+=("/etc/apt/sources.list.d/trixie-backports.list")
        fi
        sudo apt update && sudo apt install -y -t trixie-backports ydotool
        MODIFIED_PATHS+=("/usr/bin/ydotool (via trixie-backports)")
    else
        echo "--> Skipping ydotool installation per request."
    fi
}

echo "==> Setting up Human Device Interaction (HDI) Suite (Debian/Ubuntu)..."

declare -a MODIFIED_PATHS=()
declare -a INSTALLED_TOOLKITS=()
SELECTED_PKGS=()

# Toolkit 1: Autonomous Computer Use (GUI & Web Navigation)
# Note: ydotool is handled separately via install_ydotool()
COMPUTER_USE_PKGS=(
    xvfb x11-utils x11vnc wmctrl
    xdotool xclip wl-clipboard
    maim scrot imagemagick tesseract-ocr
    chromium firefox-esr
    libnss3 libatk-bridge2.0-0 libxcomposite1 libxdamage1 libxfixes3
    libxrandr2 libgbm1 libasound2 libcups2 libpango-1.0-0
    curl jq ripgrep python3 python3-pip python3-venv
)

# Toolkit 2: Automated Web Dev Frontend
WEB_DEV_PKGS=(
    nodejs npm golang python3 python3-venv
    git ripgrep fd-find jq fzf patch diffutils
    supervisor tmux make build-essential
)

echo ""
echo "Toolkit 1: Autonomous Computer Use & GUI Navigation"
echo "  Packages: xvfb, xdotool, ydotool, maim, scrot, tesseract-ocr, chromium, firefox-esr, etc."
prompt_read "Install Autonomous Computer Use suite? [Y/n]: " INSTALL_CU_RESP "Y"

if [[ "$INSTALL_CU_RESP" =~ ^[Yy]$ ]]; then
    SELECTED_PKGS+=("${COMPUTER_USE_PKGS[@]}")
    INSTALLED_TOOLKITS+=("Autonomous Computer Use (GUI & Web Navigation)")
fi

echo ""
echo "Toolkit 2: Automated Web Dev Frontend"
echo "  Packages: nodejs, npm, golang, python3, git, ripgrep, fd-find, fzf, supervisor, tmux, make, build-essential"
prompt_read "Install Automated Web Dev Frontend suite? [Y/n]: " INSTALL_WD_RESP "Y"

if [[ "$INSTALL_WD_RESP" =~ ^[Yy]$ ]]; then
    SELECTED_PKGS+=("${WEB_DEV_PKGS[@]}")
    INSTALLED_TOOLKITS+=("Automated Web Dev Frontend")
fi

# Install selected packages via APT
if [ ${#SELECTED_PKGS[@]} -gt 0 ]; then
    readarray -t UNIQUE_PKGS < <(printf "%s\n" "${SELECTED_PKGS[@]}" | sort -u)
    echo "==> Installing selected packages..."
    sudo apt update && sudo apt install -y "${UNIQUE_PKGS[@]}"
fi

# Install ydotool if Toolkit 1 was selected
if [[ "$INSTALL_CU_RESP" =~ ^[Yy]$ ]]; then
    install_ydotool
fi

# Symlinks & Utilities
mkdir -p "$HOME/.local/bin"
if command -v fdfind &>/dev/null && [ ! -f "$HOME/.local/bin/fd" ]; then
    ln -s "$(which fdfind)" "$HOME/.local/bin/fd"
    MODIFIED_PATHS+=("$HOME/.local/bin/fd (symlink -> fdfind)")
fi

LOCAL_IP="$(get_local_ip)"
TS_IP="$(get_tailscale_ip)"

# Execution Summary Block
echo ""
echo "=========================================="
echo "==> Human Device Interaction (HDI) Suite Complete"
echo "=========================================="
echo "Installed Toolkits & Packages:"
if [ ${#INSTALLED_TOOLKITS[@]} -gt 0 ]; then
    for tk in "${INSTALLED_TOOLKITS[@]}"; do
        echo "  - $tk"
    done
else
    echo "  - None selected"
fi

echo ""
echo "Modified or Created Paths:"
if [ ${#MODIFIED_PATHS[@]} -gt 0 ]; then
    for path in "${MODIFIED_PATHS[@]}"; do
        echo "  - $path"
    done
else
    echo "  - None"
fi

# NOTE FOR DEVELOPERS: Add post-installation action/service activation instructions below
# for any packages or services that require manual user setup (e.g. 'sudo tailscale up',
# 'sudo dpkg-reconfigure --priority=low unattended-upgrades', etc.).
echo ""
echo "Post-Install Action Required:"
if command -v supervisor &>/dev/null; then
    echo "  * Supervisor process manager installed! Check configuration in /etc/supervisor/supervisord.conf"
fi
if command -v ydotool &>/dev/null; then
    echo "  * ydotool installed! Ensure ydotoold daemon is running for uinput events."
fi
if [ ${#INSTALLED_TOOLKITS[@]} -eq 0 ]; then
    echo "  (No manual service activation actions required)"
fi

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
