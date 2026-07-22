#!/usr/bin/env bash
set -euo pipefail

prompt_read() {
    local prompt_text="$1"
    local target_var="$2"
    local default_val="${3:-}"
    local is_silent="${4:-false}"
    local input_val=""
    local read_flags="-r"

    [ "$is_silent" = "true" ] && read_flags="-rs"

    if [ -c /dev/tty ]; then
        read $read_flags -p "$prompt_text" input_val < /dev/tty || input_val="$default_val"
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

echo "==> Setting up Secure Headless Desktop & noVNC Web Suite (Debian/Ubuntu)..."

declare -a MODIFIED_PATHS=()
declare -a INSTALLED_COMPONENTS=()

# ==============================================================================
# UPFRONT INTERACTIVE PROMPTS
# ==============================================================================

echo ""
echo "Headless Desktop Core Suite:"
echo "  Packages: xvfb, x11-utils, x11vnc, novnc, websockify"
prompt_read "Install Headless Desktop & noVNC Web Suite? [Y/n]: " INSTALL_VNC_RESP "Y"

if [[ ! "$INSTALL_VNC_RESP" =~ ^[Yy]$ ]]; then
    echo "okay. bye. :("
    exit 0
fi

TS_SERVE_RESP="N"
if command -v tailscale &>/dev/null; then
    echo ""
    echo "Tailscale Private Mesh Exposure:"
    prompt_read "Configure 'tailscale serve' to expose noVNC over private Tailnet HTTPS? [Y/n]: " TS_SERVE_RESP "Y"
fi

echo ""
echo "⚠️ [IMPORTANT] Remote Access Recommendation:"
echo "  I recommend using Cloudflare Tunnels (cloudflared) with Cloudflare Access Controls"
echo "  for secure, zero-trust remote browser access from anywhere."
prompt_read "Install cloudflared via official Cloudflare GPG repository? [Y/n]: " INSTALL_CF_RESP "Y"

echo ""
prompt_read "Set VNC session password [default: vncpassword]: " VNC_PASS "vncpassword" "true"
echo ""

# ==============================================================================
# INSTALLATION & PROVISIONING PHASE (RUNS AFTER ALL PROMPTS ARE COMPLETE)
# ==============================================================================

APT_PKGS=(xvfb x11-utils x11vnc novnc websockify)
INSTALLED_COMPONENTS+=("Headless Desktop & noVNC Web Suite")

if [[ "$INSTALL_CF_RESP" =~ ^[Yy]$ ]]; then
    echo "==> Adding official Cloudflare GPG keyring & APT repository..."
    sudo mkdir -p --mode=0755 /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
    MODIFIED_PATHS+=("/etc/apt/sources.list.d/cloudflared.list")
    APT_PKGS+=(cloudflared)
    INSTALLED_COMPONENTS+=("Cloudflare Tunnel CLI (cloudflared)")
fi

if [ ${#APT_PKGS[@]} -gt 0 ]; then
    readarray -t UNIQUE_PKGS < <(printf "%s\n" "${APT_PKGS[@]}" | sort -u)
    echo "==> Installing selected packages via APT..."
    sudo apt update && sudo apt install -y "${UNIQUE_PKGS[@]}"
fi

# VNC Password Setup (Executed AFTER apt installation of x11vnc)
VNC_DIR="$HOME/.vnc"
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    USER_HOME="$(eval echo "~$SUDO_USER")"
    VNC_DIR="$USER_HOME/.vnc"
fi

mkdir -p "$VNC_DIR"
VNC_PW_FILE="$VNC_DIR/passwd"

if command -v x11vnc &>/dev/null; then
    echo "==> Generating VNC password file at $VNC_PW_FILE..."
    echo "y" | x11vnc -storepw "$VNC_PASS" "$VNC_PW_FILE" >/dev/null 2>&1 || \
    (printf "%s\n%s\ny\n" "$VNC_PASS" "$VNC_PASS" | x11vnc -storepw "$VNC_PW_FILE" >/dev/null 2>&1) || \
    x11vnc -storepw "$VNC_PASS" "$VNC_PW_FILE" <<< "y" >/dev/null 2>&1 || true
    
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        chown -R "$SUDO_USER:$SUDO_USER" "$VNC_DIR" 2>/dev/null || true
    fi
fi

if [ -f "$VNC_PW_FILE" ]; then
    chmod 600 "$VNC_PW_FILE"
    MODIFIED_PATHS+=("$VNC_PW_FILE")
else
    echo "⚠️  Warning: Could not create VNC password file at $VNC_PW_FILE."
fi

# Symlink noVNC vnc.html -> index.html for direct root URL access
if [ -d /usr/share/novnc ] && [ ! -f /usr/share/novnc/index.html ]; then
    sudo ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html
    MODIFIED_PATHS+=("/usr/share/novnc/index.html (symlink -> vnc.html)")
fi

# Tailscale Serve Configuration
if [[ "$TS_SERVE_RESP" =~ ^[Yy]$ ]] && command -v tailscale &>/dev/null; then
    echo "==> Configuring Tailscale Serve HTTPS proxying for port 6080..."
    sudo tailscale serve --bg 6080 2>/dev/null || true
    INSTALLED_COMPONENTS+=("Tailscale Serve HTTPS Proxy")
fi

LOCAL_IP="$(get_local_ip)"
TS_IP="$(get_tailscale_ip)"

# ==============================================================================
# EXECUTION SUMMARY & CALL TO ACTION BLOCK
# ==============================================================================
echo ""
echo "=========================================="
echo "==> Headless Desktop & noVNC Setup Complete"
echo "=========================================="
echo "Installed Components & Services:"
if [ ${#INSTALLED_COMPONENTS[@]} -gt 0 ]; then
    for comp in "${INSTALLED_COMPONENTS[@]}"; do
        echo "  - $comp"
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

echo ""
echo "Post-Install Action Required:"
echo "  * noVNC Web Desktop Status:"
if [ -n "$LOCAL_IP" ]; then
    echo "      Direct Web Desktop: http://${LOCAL_IP}:6080/"
else
    echo "      Direct Web Desktop: http://localhost:6080/"
fi

if [[ "$TS_SERVE_RESP" =~ ^[Yy]$ ]]; then
    echo "  * Tailscale Serve Status:"
    echo "      Run 'sudo tailscale serve status' to view your private HTTPS domain."
fi

if [[ "$INSTALL_CF_RESP" =~ ^[Yy]$ ]]; then
    echo "  * Cloudflare Tunnel Published Application Setup Instructions:"
    echo "      1. Log into your Cloudflare Zero Trust Dashboard (dash.teams.cloudflare.com)"
    echo "      2. Navigate to Access -> Tunnels and create a new Tunnel."
    echo "      3. Register a Published Application Route with these exact settings:"
    echo "           - Type: HTTP"
    echo "           - URL:  localhost:6080 (http://localhost:6080)"
    echo "           - Path/Hostname: Your desired subdomain (e.g. vnc.yourdomain.com)"
fi

if command -v vsec &>/dev/null; then
    echo "  * Security Posture Verification:"
    echo "      Run 'sudo vsec' to verify 127.0.0.1 loopback socket isolation for ports 5900 & 6080."
else
    echo "  * (Optional) Security Posture Verification:"
    echo "      Install 'vsec' via hardening.sh to verify loopback socket isolation for ports 5900 & 6080."
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
