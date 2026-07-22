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

echo "==> Setting up Developer Workstation (Debian/Ubuntu)..."

declare -a MODIFIED_PATHS=()
declare -a APT_MANAGED_TOOLS=()

# 1. Base APT Packages Checklist
DEFAULT_PKGS=(git jq tree zip unzip wget curl zsh xclip ripgrep fzf fd-find zoxide eza bat btop gcc ca-certificates)
SELECTED_PKGS=()

echo "Default package suite:"
echo "  ${DEFAULT_PKGS[*]}"
prompt_read "Install all default packages? [Y/n]: " INSTALL_ALL_RESP "Y"

if [[ "$INSTALL_ALL_RESP" =~ ^[Yy]$ ]]; then
    SELECTED_PKGS=("${DEFAULT_PKGS[@]}")
else
    for pkg in "${DEFAULT_PKGS[@]}"; do
        prompt_read "  Install $pkg? [Y/n]: " PKG_RESP "Y"
        if [[ "$PKG_RESP" =~ ^[Yy]$ ]]; then
            SELECTED_PKGS+=("$pkg")
        fi
    done
fi

# 2. Additional Toolchains & Binaries Checklist
EXTRA_TOOLS=(docker gh starship uv agy rust go tailscale)
SELECTED_EXTRA_TOOLS=()

echo ""
echo "Additional toolchains & services:"
echo "  ${EXTRA_TOOLS[*]}"
prompt_read "Install all additional toolchains & services? [Y/n]: " INSTALL_EXTRA_RESP "Y"

if [[ "$INSTALL_EXTRA_RESP" =~ ^[Yy]$ ]]; then
    SELECTED_EXTRA_TOOLS=("${EXTRA_TOOLS[@]}")
else
    for tool in "${EXTRA_TOOLS[@]}"; do
        prompt_read "  Install $tool? [Y/n]: " TOOL_RESP "Y"
        if [[ "$TOOL_RESP" =~ ^[Yy]$ ]]; then
            SELECTED_EXTRA_TOOLS+=("$tool")
        fi
    done
fi

is_tool_selected() {
    local target="$1"
    for t in "${SELECTED_EXTRA_TOOLS[@]}"; do
        [ "$t" = "$target" ] && return 0
    done
    return 1
}

if [ ${#SELECTED_PKGS[@]} -gt 0 ]; then
    echo "==> Installing selected APT packages..."
    sudo apt update && sudo apt install -y "${SELECTED_PKGS[@]}"
fi

# 3. Symlinks
mkdir -p "$HOME/.local/bin"
if command -v fdfind &>/dev/null && [ ! -f "$HOME/.local/bin/fd" ]; then
    ln -s "$(which fdfind)" "$HOME/.local/bin/fd"
    MODIFIED_PATHS+=("$HOME/.local/bin/fd (symlink -> fdfind)")
fi

# 4. Shell Setup & .zshrc Integration
if command -v zsh &>/dev/null; then
    ZSH_PATH="$(which zsh)"
    if [ "${SHELL:-}" != "$ZSH_PATH" ]; then
        echo "==> Setting Zsh as default shell..."
        sudo chsh -s "$ZSH_PATH" "$USER"
        MODIFIED_PATHS+=("/etc/passwd (default shell -> zsh)")
    fi

    # Deploy custom .zshrc from local repo or remote URL
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ZSHRC="$(cd "$SCRIPT_DIR/../.." && pwd)/.zshrc"
    RAW_ZSHRC_URL="https://raw.githubusercontent.com/notasandworm/install/main/.zshrc"

    echo "==> Deploying .zshrc configuration..."
    if [ -f "$HOME/.zshrc" ]; then
        BACKUP_ZSHRC="$HOME/.zshrc.bak.$(date +%Y%m%d%H%M%S)"
        cp "$HOME/.zshrc" "$BACKUP_ZSHRC"
        MODIFIED_PATHS+=("$BACKUP_ZSHRC (backup)")
    fi

    if [ -f "$REPO_ZSHRC" ]; then
        cp "$REPO_ZSHRC" "$HOME/.zshrc"
    else
        curl -fsSL "$RAW_ZSHRC_URL" -o "$HOME/.zshrc"
    fi
    MODIFIED_PATHS+=("$HOME/.zshrc")
fi

if is_tool_selected "starship" && ! command -v starship &>/dev/null; then
    echo "==> Installing Starship prompt..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    MODIFIED_PATHS+=("/usr/local/bin/starship")
fi

# 5. Docker Engine Installation (Debian Official APT Repo)
if is_tool_selected "docker" && ! command -v docker &>/dev/null; then
    echo "==> Installing Docker Engine..."
    sudo apt remove -y docker.io docker-compose docker-doc podman-docker containerd runc 2>/dev/null || true
    
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    OS_CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME:-bookworm}")"
    ARCH="$(dpkg --print-architecture)"

    sudo tee /etc/apt/sources.list.d/docker.sources <<EOF > /dev/null
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: ${OS_CODENAME}
Components: stable
Architectures: ${ARCH}
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "$USER"
    
    MODIFIED_PATHS+=("/etc/apt/sources.list.d/docker.sources")
    APT_MANAGED_TOOLS+=("Docker Engine & Docker Compose")
fi

# 6. GitHub CLI (Official APT Repo)
if is_tool_selected "gh" && ! command -v gh &>/dev/null; then
    echo "==> Installing GitHub CLI..."
    sudo mkdir -p -m 755 /etc/apt/keyrings
    wget -nv -O- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    ARCH="$(dpkg --print-architecture)"
    echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update && sudo apt install -y gh
    
    MODIFIED_PATHS+=("/etc/apt/sources.list.d/github-cli.list")
    APT_MANAGED_TOOLS+=("GitHub CLI (gh)")
fi

# 7. Standalone Binaries & Toolchains
if is_tool_selected "uv" && ! command -v uv &>/dev/null; then
    echo "==> Installing uv (Python package manager)..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    MODIFIED_PATHS+=("$HOME/.local/bin/uv")
fi

if is_tool_selected "agy" && ! command -v agy &>/dev/null; then
    echo "==> Installing Antigravity CLI (agy)..."
    curl -fsSL https://antigravity.google/cli/install.sh | bash || true
fi

if is_tool_selected "rust" && ! command -v rustc &>/dev/null; then
    echo "==> Installing Rust Toolchain..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    MODIFIED_PATHS+=("$HOME/.cargo/bin/rustc")
fi

if is_tool_selected "go" && ! command -v go &>/dev/null; then
    echo "==> Installing Go Toolchain..."
    GO_VER="1.24.5"
    wget -q "https://go.dev/dl/go${GO_VER}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    rm /tmp/go.tar.gz
    MODIFIED_PATHS+=("/usr/local/go")
fi

if is_tool_selected "tailscale" && ! command -v tailscale &>/dev/null; then
    echo "==> Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    MODIFIED_PATHS+=("/usr/bin/tailscale")
    APT_MANAGED_TOOLS+=("Tailscale")
fi

# 8. Execution Summary & Review Block
echo ""
echo "=========================================="
echo "==> Workstation Provisioning Complete"
echo "=========================================="

echo "Installed Packages & Tools:"
if [ ${#SELECTED_PKGS[@]} -gt 0 ]; then
    echo "  - Base APT Packages: ${SELECTED_PKGS[*]}"
fi
if [ ${#SELECTED_EXTRA_TOOLS[@]} -gt 0 ]; then
    echo "  - Additional Toolchains & Services: ${SELECTED_EXTRA_TOOLS[*]}"
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
if is_tool_selected "tailscale"; then
    echo "  * Tailscale installed! To authenticate and connect to your mesh network, run:"
    echo "      sudo tailscale up"
else
    echo "  (No manual service activation actions required)"
fi

