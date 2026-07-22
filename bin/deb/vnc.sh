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

APT_PKGS=(xvfb x11-utils x11vnc novnc websockify python3)
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

# VNC Password Setup (Executed AFTER apt installation of x11vnc & python3)
VNC_DIR="$HOME/.vnc"
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    USER_HOME="$(eval echo "~$SUDO_USER")"
    VNC_DIR="$USER_HOME/.vnc"
fi

mkdir -p "$VNC_DIR"
VNC_PW_FILE="$VNC_DIR/passwd"

echo "==> Generating VNC password file at $VNC_PW_FILE..."
if command -v python3 &>/dev/null; then
    VNC_PASS="$VNC_PASS" VNC_PW_FILE="$VNC_PW_FILE" python3 -c "
import os, sys
def create_vnc_passwd(password, filepath):
    PI = [58, 50, 42, 34, 26, 18, 10, 2, 60, 52, 44, 36, 28, 20, 12, 4, 62, 54, 46, 38, 30, 22, 14, 6, 64, 56, 48, 40, 32, 24, 16, 8, 57, 49, 41, 33, 25, 17, 9, 1, 59, 51, 43, 35, 27, 19, 11, 3, 61, 53, 45, 37, 29, 21, 13, 5, 63, 55, 47, 39, 31, 23, 15, 7]
    FP = [40, 8, 48, 16, 56, 24, 64, 32, 39, 7, 47, 15, 55, 23, 63, 31, 38, 6, 46, 14, 54, 22, 62, 30, 37, 5, 45, 13, 53, 21, 61, 29, 36, 4, 44, 12, 52, 20, 60, 28, 35, 3, 43, 11, 51, 19, 59, 27]
    CP_1 = [57, 49, 41, 33, 25, 17, 9, 1, 58, 50, 42, 34, 26, 18, 10, 2, 59, 51, 43, 35, 27, 19, 11, 3, 60, 52, 44, 36, 63, 55, 47, 39, 31, 23, 15, 7, 62, 54, 46, 38, 30, 22, 14, 6, 61, 53, 45, 37, 29, 21, 13, 5, 28, 20, 12, 4]
    CP_2 = [14, 17, 11, 24, 1, 5, 3, 28, 15, 6, 21, 10, 23, 19, 12, 4, 26, 8, 16, 7, 27, 20, 13, 2, 41, 52, 31, 37, 47, 55, 30, 40, 51, 45, 33, 48, 44, 49, 39, 56, 34, 53, 46, 42, 50, 36, 29, 32]
    SHIFTS = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1]
    E = [32, 1, 2, 3, 4, 5, 4, 5, 6, 7, 8, 9, 8, 9, 10, 11, 12, 13, 12, 13, 14, 15, 16, 17, 16, 17, 18, 19, 20, 21, 20, 21, 22, 23, 24, 25, 24, 25, 26, 27, 28, 29, 28, 29, 30, 31, 32, 1]
    S = [
        [[14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7], [0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8], [4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0], [15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13]],
        [[15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10], [3, 13, 4, 7, 15, 2, 8, 14, 12, 0, 1, 10, 6, 9, 11, 5], [0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15], [13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9]],
        [[10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8], [13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1], [13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7], [1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12]],
        [[7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15], [13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9], [10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4], [3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14]],
        [[2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9], [14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6], [4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14], [11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3]],
        [[12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11], [10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8], [9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6], [4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13]],
        [[4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1], [13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6], [1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2], [6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12]],
        [[13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7], [1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2], [7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8], [2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11]]
    ]
    P = [16, 7, 20, 21, 29, 12, 28, 17, 1, 15, 23, 26, 5, 18, 31, 10, 2, 8, 24, 14, 32, 27, 3, 9, 19, 13, 30, 6, 22, 11, 4, 25]
    def permute(block, table): return [block[x - 1] for x in table]
    def bits_to_bytes(bits): return bytes(sum(bits[i + j] << (7 - j) for j in range(8)) for i in range(0, len(bits), 8))
    def bytes_to_bits(data): return [int(b) for byte in data for b in format(byte, '08b')]
    def des_encrypt(data_bytes, key_bytes):
        data_bits = bytes_to_bits(data_bytes)
        key_bits = bytes_to_bits(key_bytes)
        key_p = permute(key_bits, CP_1)
        L_k, R_k = key_p[:28], key_p[28:]
        keys = []
        for shift in SHIFTS:
            L_k = L_k[shift:] + L_k[:shift]
            R_k = R_k[shift:] + R_k[:shift]
            keys.append(permute(L_k + R_k, CP_2))
        p_bits = permute(data_bits, PI)
        L, R = p_bits[:32], p_bits[32:]
        for k in keys:
            E_R = permute(R, E)
            X = [a ^ b for a, b in zip(E_R, k)]
            S_out = []
            for i in range(8):
                block = X[i*6:(i+1)*6]
                row = (block[0] << 1) | block[5]
                col = (block[1] << 3) | (block[2] << 2) | (block[3] << 1) | block[4]
                val = S[i][row][col]
                S_out.extend([int(b) for b in format(val, '04b')])
            f_res = permute(S_out, P)
            L, R = R, [a ^ b for a, b in zip(L, f_res)]
        final_bits = permute(R + L, FP)
        return bits_to_bytes(final_bits)
    def reverse_bits(b): return sum((1 if (b & (1 << i)) else 0) << (7 - i) for i in range(8))
    raw_key = [0xe8, 0x4a, 0xd6, 0x60, 0x14, 0xbf, 0xd8, 0x10]
    vnc_key = bytes([reverse_bits(b) for b in raw_key])
    pwd = (os.environ.get('VNC_PASS', 'vncpassword')[:8].ljust(8, '\x00')).encode('latin1')
    encrypted = des_encrypt(pwd, vnc_key)
    with open(os.environ.get('VNC_PW_FILE'), 'wb') as f: f.write(encrypted)

create_vnc_passwd(os.environ.get('VNC_PASS', 'vncpassword'), os.environ.get('VNC_PW_FILE'))
" 2>/dev/null || true
fi

# Secondary fallback to x11vnc CLI if Python script was not used
if [ ! -f "$VNC_PW_FILE" ] && command -v x11vnc &>/dev/null; then
    (printf "%s\n%s\ny\n" "$VNC_PASS" "$VNC_PASS" | x11vnc -storepw "$VNC_PW_FILE" >/dev/null 2>&1) || true
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
