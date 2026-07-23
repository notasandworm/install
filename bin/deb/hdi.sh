#!/usr/bin/env bash
set -euo pipefail

# Check for non-interactive flags
ASSUME_YES=false
for arg in "$@"; do
    if [ "$arg" = "-y" ] || [ "$arg" = "--yes" ]; then
        ASSUME_YES=true
    fi
done

prompt_read() {
    local prompt_text="$1"
    local target_var="$2"
    local default_val="${3:-}"
    local input_val=""

    if [ "${ASSUME_YES:-false}" = "true" ] || [ "${NONINTERACTIVE:-false}" = "1" ]; then
        input_val="$default_val"
    elif [ -c /dev/tty ]; then
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

check_ydotool_needs_backports() {
    if command -v ydotool &>/dev/null; then
        return 1
    fi
    if apt-cache policy ydotool 2>/dev/null | grep -q "Candidate:" && ! apt-cache policy ydotool 2>/dev/null | grep -q "Candidate: (none)"; then
        return 1
    fi
    return 0
}

echo "==> Setting up Human Device Interaction (HDI) Suite (Debian/Ubuntu)..."

declare -a MODIFIED_PATHS=()
declare -a INSTALLED_TOOLKITS=()
SELECTED_PKGS=()

# Toolkit 1: Autonomous Computer Use (GUI & Web Navigation)
COMPUTER_USE_PKGS=(
    xvfb x11-utils x11vnc wmctrl ffmpeg
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

ENABLE_BACKPORTS=false
NEEDS_BACKPORTS=false

if check_ydotool_needs_backports; then
    NEEDS_BACKPORTS=true
fi

# ==============================================================================
# UPFRONT USER PROMPTS
# ==============================================================================

echo ""
echo "Toolkit 1: Autonomous Computer Use & GUI Navigation"
echo "  Packages: xvfb, xdotool, ydotool, maim, scrot, tesseract-ocr, chromium, firefox-esr, etc."

if [ "$NEEDS_BACKPORTS" = "true" ]; then
    echo "⚠️  Warning: 'ydotool' is not in default Debian main. Installing Toolkit 1 requires adding official 'trixie-backports'."
fi

prompt_read "Install Autonomous Computer Use suite? [Y/n]: " INSTALL_CU_RESP "Y"

if [[ "$INSTALL_CU_RESP" =~ ^[Yy]$ ]]; then
    if [ "$NEEDS_BACKPORTS" = "true" ]; then
        prompt_read "I understand the risks of potential library dependency conflicts, untested software interactions, and slower security patching (worth it for this use case!) [y/N]: " ACK_RISK_RESP "N"
        if [[ "$ACK_RISK_RESP" =~ ^[Yy]$ ]]; then
            ENABLE_BACKPORTS=true
            SELECTED_PKGS+=("${COMPUTER_USE_PKGS[@]}")
            INSTALLED_TOOLKITS+=("Autonomous Computer Use (GUI & Web Navigation)")
        else
            echo "okay. thanks. bye. :("
        fi
    else
        SELECTED_PKGS+=("${COMPUTER_USE_PKGS[@]}")
        SELECTED_PKGS+=("ydotool")
        INSTALLED_TOOLKITS+=("Autonomous Computer Use (GUI & Web Navigation)")
    fi
fi

echo ""
echo "Toolkit 2: Automated Web Dev Frontend"
echo "  Packages: nodejs, npm, golang, python3, git, ripgrep, fd-find, fzf, supervisor, tmux, make, build-essential"
prompt_read "Install Automated Web Dev Frontend suite? [Y/n]: " INSTALL_WD_RESP "Y"

if [[ "$INSTALL_WD_RESP" =~ ^[Yy]$ ]]; then
    SELECTED_PKGS+=("${WEB_DEV_PKGS[@]}")
    INSTALLED_TOOLKITS+=("Automated Web Dev Frontend")
fi

echo ""
prompt_read "Copy Computer Use Recipes manual to your home folder? [Y/n]: " COPY_RECIPES_RESP "Y"

# ==============================================================================
# INSTALLATION & PROVISIONING PHASE (RUNS AFTER ALL PROMPTS ARE COMPLETE)
# ==============================================================================

if [ "$ENABLE_BACKPORTS" = "true" ]; then
    echo "==> Configuring trixie-backports repository..."
    if [ ! -f /etc/apt/sources.list.d/trixie-backports.list ]; then
        echo "deb http://deb.debian.org/debian trixie-backports main" | sudo tee /etc/apt/sources.list.d/trixie-backports.list > /dev/null
        MODIFIED_PATHS+=("/etc/apt/sources.list.d/trixie-backports.list")
    fi
    sudo apt update
    echo "==> Installing ydotool via trixie-backports..."
    sudo apt install -y -t trixie-backports ydotool || true
    MODIFIED_PATHS+=("/usr/bin/ydotool (via trixie-backports)")
fi

if [ ${#SELECTED_PKGS[@]} -gt 0 ]; then
    readarray -t UNIQUE_PKGS < <(printf "%s\n" "${SELECTED_PKGS[@]}" | sort -u)
    echo "==> Installing selected packages via APT..."
    sudo apt update && sudo apt install -y "${UNIQUE_PKGS[@]}"
fi

# Determine the real user and home directory running the script
REAL_USER="$USER"
REAL_HOME="$HOME"
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME="$(eval echo "~$SUDO_USER")"
fi

# Symlinks & Utilities
mkdir -p "$REAL_HOME/.local/bin"
if command -v fdfind &>/dev/null && [ ! -f "$REAL_HOME/.local/bin/fd" ]; then
    ln -sf "$(which fdfind)" "$REAL_HOME/.local/bin/fd"
    MODIFIED_PATHS+=("$REAL_HOME/.local/bin/fd (symlink -> fdfind)")
fi

# Python virtual environment setup for Computer Use
if [[ "$INSTALL_CU_RESP" =~ ^[Yy]$ ]]; then
    VENV_PATH="$REAL_HOME/.computer-use-venv"
    echo "==> Setting up Python virtual environment for computer use at $VENV_PATH..."
    python3 -m venv "$VENV_PATH"
    "$VENV_PATH/bin/pip" install --upgrade pip >/dev/null 2>&1 || true
    echo "==> Installing Python GUI & Automation libraries (mss, pyautogui, pillow, opencv-python-headless, pytesseract, playwright)..."
    "$VENV_PATH/bin/pip" install mss pyautogui pillow opencv-python-headless pytesseract playwright >/dev/null 2>&1 || true
    
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        chown -R "$SUDO_USER:$SUDO_USER" "$VENV_PATH" 2>/dev/null || true
        chown -R "$SUDO_USER:$SUDO_USER" "$REAL_HOME/.local" 2>/dev/null || true
    fi
    MODIFIED_PATHS+=("$VENV_PATH (Python Virtualenv)")
fi

# Configure ydotool systemd service and permissions if installed
if command -v ydotool &>/dev/null; then
    echo "==> Configuring ydotool systemd service..."
    sudo tee /etc/systemd/system/ydotool.service > /dev/null << 'EOF'
[Unit]
Description=ydotool automation daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ydotoold --socket-path=/tmp/.ydotool_socket --socket-own=nobody:input --socket-perm=0660
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

    MODIFIED_PATHS+=("/etc/systemd/system/ydotool.service")

    # Add the local user to the input group to access the socket
    sudo usermod -aG input "${REAL_USER}" || true

    echo "==> Enabling and starting ydotool service..."
    sudo systemctl daemon-reload
    sudo systemctl enable --now ydotool 2>/dev/null || true
fi

# Copy or download Computer Use Recipes manual to the consumer's home folder
if [[ "$COPY_RECIPES_RESP" =~ ^[Yy]$ ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd 2>/dev/null || pwd)"
    SRC_RECIPES="${SCRIPT_DIR}/../../docs/computer_use_recipes.md"
    DEST_RECIPES="$REAL_HOME/computer_use_recipes.md"
    
    if [ -f "$SRC_RECIPES" ]; then
        echo "==> Copying Computer Use Recipes to $DEST_RECIPES..."
        cp "$SRC_RECIPES" "$DEST_RECIPES"
        [ -n "${SUDO_USER:-}" ] && chown "$SUDO_USER:$SUDO_USER" "$DEST_RECIPES" 2>/dev/null || true
        MODIFIED_PATHS+=("$DEST_RECIPES")
    elif command -v curl &>/dev/null; then
        echo "==> Downloading Computer Use Recipes from GitHub to $DEST_RECIPES..."
        curl -fsSL "https://raw.githubusercontent.com/notasandworm/install/main/docs/computer_use_recipes.md" -o "$DEST_RECIPES" || true
        if [ -f "$DEST_RECIPES" ]; then
            [ -n "${SUDO_USER:-}" ] && chown "$SUDO_USER:$SUDO_USER" "$DEST_RECIPES" 2>/dev/null || true
            MODIFIED_PATHS+=("$DEST_RECIPES")
        fi
    elif command -v wget &>/dev/null; then
        echo "==> Downloading Computer Use Recipes from GitHub to $DEST_RECIPES..."
        wget -qO "$DEST_RECIPES" "https://raw.githubusercontent.com/notasandworm/install/main/docs/computer_use_recipes.md" || true
        if [ -f "$DEST_RECIPES" ]; then
            [ -n "${SUDO_USER:-}" ] && chown "$SUDO_USER:$SUDO_USER" "$DEST_RECIPES" 2>/dev/null || true
            MODIFIED_PATHS+=("$DEST_RECIPES")
        fi
    fi
fi

LOCAL_IP="$(get_local_ip)"
TS_IP="$(get_tailscale_ip)"

# ==============================================================================
# EXECUTION SUMMARY BLOCK
# ==============================================================================
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
    echo "  * ydotool service is active! Run it without sudo: export YDOTOOL_SOCKET=/tmp/.ydotool_socket && ydotool click 1"
fi
if [ -d "$REAL_HOME/.computer-use-venv" ]; then
    echo "  * Python Virtualenv created! Activate it: source ~/.computer-use-venv/bin/activate"
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
