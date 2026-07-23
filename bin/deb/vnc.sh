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
    local is_silent="${4:-false}"
    local input_val=""
    local read_flags="-r"

    [ "$is_silent" = "true" ] && read_flags="-rs"

    if [ "${ASSUME_YES:-false}" = "true" ] || [ "${NONINTERACTIVE:-false}" = "1" ]; then
        input_val="$default_val"
    elif [ -c /dev/tty ]; then
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
echo "Lightweight Desktop Environment:"
prompt_read "Install lightweight XFCE4 desktop environment? (Recommended if not already installed) [Y/n]: " INSTALL_XFCE_RESP "Y"

echo ""
echo "Background Process Manager (Systemd):"
prompt_read "Enable and start noVNC systemd background service? [Y/n]: " START_SERVICE_RESP "Y"

# Package Necessity Review Table
echo ""
echo "================================================================================"
echo "Packages & Services Overview:"
echo "--------------------------------------------------------------------------------"
echo "REQUIRED CORE DESKTOP COMPONENTS:"
echo "  * xvfb       - Virtual X11 framebuffer in memory (runs GUI apps headless)"
echo "  * x11-utils  - Window inspection & management tools (xwd, xwininfo)"
echo "  * x11vnc     - VNC daemon converting X11 draw events to RFB protocol (127.0.0.1:5900)"
echo "  * novnc      - HTML5 JavaScript web desktop UI assets (vnc.html / index.html)"
echo "  * websockify - WebSockets-to-TCP proxy bridging web browser to VNC (127.0.0.1:6080)"
if [[ "$INSTALL_XFCE_RESP" =~ ^[Yy]$ ]]; then
    echo "  * xfce4      - Lightweight desktop environment (for a full graphical GUI) [SELECTED]"
else
    echo "  * xfce4      - Lightweight desktop environment [SKIPPED]"
fi
echo ""
echo "OPTIONAL TRANSPORT & SYSTEM COMPONENTS:"
if [[ "$INSTALL_CF_RESP" =~ ^[Yy]$ ]]; then
    echo "  * cloudflared - Cloudflare Tunnel CLI for zero-trust remote access [SELECTED]"
else
    echo "  * cloudflared - Cloudflare Tunnel CLI [SKIPPED]"
fi
if [[ "$TS_SERVE_RESP" =~ ^[Yy]$ ]]; then
    echo "  * tailscale   - Private WireGuard mesh network HTTPS proxying [SELECTED]"
fi
if [[ "$START_SERVICE_RESP" =~ ^[Yy]$ ]]; then
    echo "  * systemd svc - Create and enable 'novnc' systemd background service [SELECTED]"
else
    echo "  * systemd svc - Create and enable 'novnc' systemd background service [SKIPPED]"
fi
echo "================================================================================"
echo ""
prompt_read "Review and continue [Y/n]: " REVIEW_RESP "Y"

if [[ ! "$REVIEW_RESP" =~ ^[Yy]$ ]]; then
    echo "okay. bye. :("
    exit 0
fi

echo ""
prompt_read "Set VNC session password [default: vncpassword]: " VNC_PASS "vncpassword" "true"
echo ""

# ==============================================================================
# INSTALLATION & PROVISIONING PHASE (RUNS AFTER ALL PROMPTS ARE COMPLETE)
# ==============================================================================

APT_PKGS=(xvfb x11-utils x11vnc novnc websockify python3)
INSTALLED_COMPONENTS+=("Headless Desktop & noVNC Web Suite")

if [[ "$INSTALL_XFCE_RESP" =~ ^[Yy]$ ]]; then
    APT_PKGS+=(xfce4 dbus-x11)
    INSTALLED_COMPONENTS+=("XFCE4 Desktop Environment & DBus")
fi

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
    sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt install -y "${UNIQUE_PKGS[@]}"
fi

# VNC Password Setup (Executed AFTER apt installation of x11vnc & python3)
REAL_USER="$USER"
REAL_HOME="$HOME"
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME="$(eval echo "~$SUDO_USER")"
fi

VNC_DIR="$REAL_HOME/.vnc"
VNC_PW_FILE="$VNC_DIR/passwd"

echo "==> Generating VNC password file at $VNC_PW_FILE..."
mkdir -p "$VNC_DIR"
if command -v x11vnc &>/dev/null; then
    x11vnc -storepasswd "$VNC_PASS" "$VNC_PW_FILE" >/dev/null 2>&1 || true
fi

if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    chown -R "$SUDO_USER:$SUDO_USER" "$VNC_DIR" 2>/dev/null || true
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

# Determine the real user and home directory running the service
REAL_USER="$USER"
REAL_HOME="$HOME"
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME="$(eval echo "~$SUDO_USER")"
fi

# Create start-novnc wrapper script
echo "==> Creating noVNC startup wrapper script at /usr/local/bin/start-novnc.sh..."
sudo tee /usr/local/bin/start-novnc.sh > /dev/null << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Pre-flight check: ensure VNC password file exists
if [ ! -f "$HOME/.vnc/passwd" ]; then
    echo "FATAL: VNC password file missing at $HOME/.vnc/passwd." >&2
    echo "Please set one by running: x11vnc -storepasswd <your-password> ~/.vnc/passwd" >&2
    exit 1
fi

export DISPLAY=:99
rm -f /tmp/.X99-lock

# 1. Start virtual display
Xvfb :99 -screen 0 1920x1080x24 &
sleep 1

# 2. Start Desktop Environment / Window Manager
if command -v startxfce4 &>/dev/null; then
    startxfce4 &
elif command -v xfce4-session &>/dev/null; then
    xfce4-session &
elif command -v openbox-session &>/dev/null; then
    openbox-session &
elif command -v lxsession &>/dev/null; then
    lxsession &
elif command -v mate-session &>/dev/null; then
    mate-session &
elif command -v gnome-session &>/dev/null; then
    gnome-session &
else
    echo "WARNING: No desktop environment/window manager found. noVNC will run with a blank screen." >&2
fi

# 3. Start VNC server bound strictly to localhost
x11vnc -display :99 -rfbport 5900 -rfbauth "$HOME/.vnc/passwd" -forever -shared -localhost &

# 4. Start noVNC WebSockets proxy on port 6080
exec websockify --web /usr/share/novnc 127.0.0.1:6080 127.0.0.1:5900
EOF

sudo chmod +x /usr/local/bin/start-novnc.sh
MODIFIED_PATHS+=("/usr/local/bin/start-novnc.sh")

# Create systemd service file
echo "==> Creating systemd service file at /etc/systemd/system/novnc.service..."
sudo tee /etc/systemd/system/novnc.service > /dev/null << EOF
[Unit]
Description=Headless X11 + noVNC Web Desktop
After=network.target

[Service]
Type=simple
User=${REAL_USER}
Environment=HOME=${REAL_HOME}
ExecStart=/usr/local/bin/start-novnc.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

MODIFIED_PATHS+=("/etc/systemd/system/novnc.service")

# Enable and start the service if requested
if [[ "$START_SERVICE_RESP" =~ ^[Yy]$ ]]; then
    echo "==> Reloading systemd daemon, enabling and starting 'novnc' service..."
    sudo systemctl daemon-reload
    sudo systemctl enable --now novnc
    INSTALLED_COMPONENTS+=("noVNC systemd Service (running as ${REAL_USER})")
else
    echo "==> systemd service 'novnc' created but NOT enabled/started."
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

if [[ "$START_SERVICE_RESP" =~ ^[Yy]$ ]]; then
    echo "  * noVNC Background Service Verification:"
    echo "      Check service status:   sudo systemctl status novnc"
    echo "      View service logs:      sudo journalctl -u novnc -f"
    echo "      Verify port binding:    sudo ss -tulpn | grep -E '6080|5900'"
    echo "  * Change VNC Password:"
    echo "      Run: x11vnc -storepasswd <new-password> ~/.vnc/passwd"
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
