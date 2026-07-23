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

echo "==> QEMU / KVM Virtualization & AI Agent Test Suite Setup (Debian/Ubuntu)"

# Initial Toolkit Confirmation
echo ""
prompt_read "Install QEMU/KVM package suite & test harness? [Y/n]: " INSTALL_TOOLKIT_RESP "Y"

if [[ ! "$INSTALL_TOOLKIT_RESP" =~ ^[Yy]$ ]]; then
    echo "==> Setup cancelled by user. Exiting without modifying system."
    exit 0
fi

declare -a INSTALLED_COMPONENTS=()

KVM_PKGS=(
    qemu-system-x86
    qemu-utils
    cloud-image-utils
    cpu-checker
    bridge-utils
    openssh-client
    genisoimage
    wget
    curl
    jq
)

echo ""
echo "QEMU/KVM Package Suite:"
echo "  ${KVM_PKGS[*]}"

echo "==> Updating APT package index..."
sudo apt-get update
echo "==> Installing QEMU/KVM packages..."
sudo apt-get install -y "${KVM_PKGS[@]}"
INSTALLED_COMPONENTS+=("QEMU/KVM Core Packages")

# Hardware Virtualization Check
echo ""
echo "==> Verifying KVM hardware acceleration support..."
if [ -c /dev/kvm ]; then
    echo "✅ KVM device node /dev/kvm is present."
else
    echo "⚠️  Warning: /dev/kvm was not detected. Ensure CPU virtualization (VT-x / AMD-V) is enabled in BIOS/nested KVM."
fi

if command -v kvm-ok &>/dev/null; then
    kvm-ok || true
fi

# KVM Group Permissions
if [ -n "${USER:-}" ] && [ "$USER" != "root" ]; then
    if id -nG "$USER" | grep -qw "kvm"; then
        echo "✅ User '$USER' is already a member of the 'kvm' group."
    else
        prompt_read "Add user '$USER' to 'kvm' group for non-root KVM access? [Y/n]: " ADD_KVM_RESP "Y"
        if [[ "$ADD_KVM_RESP" =~ ^[Yy]$ ]]; then
            sudo usermod -aG kvm "$USER"
            echo "✅ Added '$USER' to 'kvm' group. (Note: Log out and back in for group changes to take effect)."
            INSTALLED_COMPONENTS+=("KVM Group Permissions for $USER")
        fi
    fi
fi

# Base Image Cache Setup & Granular Prompts
CACHE_DIR="${HOME}/.cache/qemu-test-images"
mkdir -p "$CACHE_DIR"

DEBIAN12_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
DEBIAN13_URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
ARCH_URL="https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-basic.qcow2"

echo ""
echo "Base Cloud Images Caching (~/.cache/qemu-test-images):"
prompt_read "Pre-download baseline QCOW2 cloud images now? [y/N]: " DOWNLOAD_IMAGES_RESP "N"

if [[ "$DOWNLOAD_IMAGES_RESP" =~ ^[Yy]$ ]]; then
    # 1. Debian 12 (Bookworm)
    echo ""
    if [ -f "$CACHE_DIR/debian-12-generic-amd64.qcow2" ]; then
        prompt_read "Debian 12 image is already cached. Re-download / overwrite? [y/N]: " DL_DEB12 "N"
    else
        prompt_read "Download Debian 12 (Bookworm) Cloud Image? [Y/n]: " DL_DEB12 "Y"
    fi
    if [[ "$DL_DEB12" =~ ^[Yy]$ ]]; then
        echo "==> Downloading Debian 12 (Bookworm) Cloud Image..."
        wget -q --show-progress -O "$CACHE_DIR/debian-12-generic-amd64.qcow2" "$DEBIAN12_URL"
        INSTALLED_COMPONENTS+=("Cached Debian 12 (Bookworm) Image")
    fi

    # 2. Debian 13 (Trixie)
    echo ""
    if [ -f "$CACHE_DIR/debian-13-generic-amd64.qcow2" ]; then
        prompt_read "Debian 13 image is already cached. Re-download / overwrite? [y/N]: " DL_DEB13 "N"
    else
        prompt_read "Download Debian 13 (Trixie) Cloud Image? [y/N]: " DL_DEB13 "N"
    fi
    if [[ "$DL_DEB13" =~ ^[Yy]$ ]]; then
        echo "==> Downloading Debian 13 (Trixie) Cloud Image..."
        wget -q --show-progress -O "$CACHE_DIR/debian-13-generic-amd64.qcow2" "$DEBIAN13_URL"
        INSTALLED_COMPONENTS+=("Cached Debian 13 (Trixie) Image")
    fi

    # 3. Arch Linux
    echo ""
    if [ -f "$CACHE_DIR/arch-linux-x86_64-basic.qcow2" ]; then
        prompt_read "Arch Linux image is already cached. Re-download / overwrite? [y/N]: " DL_ARCH "N"
    else
        prompt_read "Download Arch Linux Cloud Image? [y/N]: " DL_ARCH "N"
    fi
    if [[ "$DL_ARCH" =~ ^[Yy]$ ]]; then
        echo "==> Downloading Arch Linux Cloud Image..."
        wget -q --show-progress -O "$CACHE_DIR/arch-linux-x86_64-basic.qcow2" "$ARCH_URL"
        INSTALLED_COMPONENTS+=("Cached Arch Linux Image")
    fi
fi

# Safe BASH_SOURCE resolution for piped stdin vs local file execution
SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
LOCAL_HARNESS=""

if [ -n "$SCRIPT_SOURCE" ] && [ "$SCRIPT_SOURCE" != "-" ] && [ -f "$SCRIPT_SOURCE" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
    REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    if [ -f "$REPO_ROOT/bin/qemu-vm" ]; then
        LOCAL_HARNESS="$REPO_ROOT/bin/qemu-vm"
    fi
fi

echo ""
if [ -n "$LOCAL_HARNESS" ]; then
    chmod +x "$LOCAL_HARNESS"
    if [ -w /usr/local/bin ]; then
        cp "$LOCAL_HARNESS" /usr/local/bin/qemu-vm
    else
        sudo cp "$LOCAL_HARNESS" /usr/local/bin/qemu-vm
        sudo chmod +x /usr/local/bin/qemu-vm
    fi
    echo "✅ Installed 'qemu-vm' harness to /usr/local/bin/qemu-vm"
    INSTALLED_COMPONENTS+=("Installed qemu-vm CLI to /usr/local/bin")
else
    echo "==> Fetching latest 'qemu-vm' harness from GitHub..."
    if [ -w /usr/local/bin ]; then
        curl -fsSL https://raw.githubusercontent.com/notasandworm/install/feat-ability-qemu/bin/qemu-vm -o /usr/local/bin/qemu-vm
        chmod +x /usr/local/bin/qemu-vm
    else
        sudo curl -fsSL https://raw.githubusercontent.com/notasandworm/install/feat-ability-qemu/bin/qemu-vm -o /usr/local/bin/qemu-vm
        sudo chmod +x /usr/local/bin/qemu-vm
    fi
    echo "✅ Installed 'qemu-vm' harness to /usr/local/bin/qemu-vm"
    INSTALLED_COMPONENTS+=("Installed qemu-vm CLI to /usr/local/bin")
fi

echo ""
echo "=============================================================================="
echo "🎉 Yay us! QEMU / KVM Provisioning Complete!"
echo "=============================================================================="
echo "Ephemeral KVM testing now available."
echo ""
echo "Installed Components:"
for item in "${INSTALLED_COMPONENTS[@]}"; do
    echo "  - $item"
done

echo ""
echo "Usage:"
echo "  Run virtual machines via qemu-system-x86_64:"
echo "    qemu-vm run --os debian12 --script bin/deb/dev.sh"
echo "    qemu-vm run --os debian13 --script bin/deb/hdi.sh"
echo "    qemu-vm run --os arch --script bin/deb/vnc.sh"
echo "=============================================================================="
