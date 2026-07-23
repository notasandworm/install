#!/usr/bin/env bash
set -euo pipefail

prompt_read() {
    local prompt_text="$1"
    local target_var="$2"
    local default_val="${3:-}"
    local input_val=""

    if [ -t 0 ] && [ -c /dev/tty ]; then
        read -r -p "$prompt_text" input_val < /dev/tty || input_val="$default_val"
    else
        read -r -p "$prompt_text" input_val || input_val="$default_val"
    fi
    eval "$target_var=\"\${input_val:-\$default_val}\""
}

echo "==> QEMU / KVM Virtualization & AI Agent Test Suite Setup (Arch Linux)"

# Initial Toolkit Confirmation
echo ""
prompt_read "Install QEMU/KVM package suite & test harness? [Y/n]: " INSTALL_TOOLKIT_RESP "Y"

if [[ ! "$INSTALL_TOOLKIT_RESP" =~ ^[Yy]$ ]]; then
    echo "==> Setup cancelled by user. Exiting without modifying system."
    exit 0
fi

declare -a INSTALLED_COMPONENTS=()

KVM_PKGS=(
    qemu-desktop
    qemu-img
    cloud-utils
    cdrtools
    openssh
    wget
    curl
    jq
)

echo ""
echo "QEMU/KVM Pacman Package Suite:"
echo "  ${KVM_PKGS[*]}"

echo "==> Synchronizing pacman database & installing packages..."
sudo pacman -Sy --needed --noconfirm "${KVM_PKGS[@]}"
INSTALLED_COMPONENTS+=("QEMU/KVM Arch Core Packages")

# Hardware Virtualization Check
echo ""
echo "==> Verifying KVM hardware acceleration support..."
if [ -c /dev/kvm ]; then
    echo "✅ KVM device node /dev/kvm is present."
else
    echo "⚠️  Warning: /dev/kvm was not detected. Ensure CPU virtualization (VT-x / AMD-V) is enabled in BIOS/nested KVM."
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

ARCH_URL="https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-basic.qcow2"
DEBIAN12_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
DEBIAN13_URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"

echo ""
echo "Base Cloud Images Caching (~/.cache/qemu-test-images):"
prompt_read "Pre-download baseline QCOW2 cloud images now? [y/N]: " DOWNLOAD_IMAGES_RESP "N"

if [[ "$DOWNLOAD_IMAGES_RESP" =~ ^[Yy]$ ]]; then
    # 1. Arch Linux
    echo ""
    if [ -f "$CACHE_DIR/arch-linux-x86_64-basic.qcow2" ]; then
        prompt_read "Arch Linux image is already cached. Re-download / overwrite? [y/N]: " DL_ARCH "N"
    else
        prompt_read "Download Arch Linux Cloud Image? [Y/n]: " DL_ARCH "Y"
    fi
    if [[ "$DL_ARCH" =~ ^[Yy]$ ]]; then
        echo "==> Downloading Arch Linux Cloud Image..."
        wget -q --show-progress -O "$CACHE_DIR/arch-linux-x86_64-basic.qcow2" "$ARCH_URL"
        INSTALLED_COMPONENTS+=("Cached Arch Linux Image")
    fi

    # 2. Debian 12 (Bookworm)
    echo ""
    if [ -f "$CACHE_DIR/debian-12-generic-amd64.qcow2" ]; then
        prompt_read "Debian 12 image is already cached. Re-download / overwrite? [y/N]: " DL_DEB12 "N"
    else
        prompt_read "Download Debian 12 (Bookworm) Cloud Image? [y/N]: " DL_DEB12 "N"
    fi
    if [[ "$DL_DEB12" =~ ^[Yy]$ ]]; then
        echo "==> Downloading Debian 12 (Bookworm) Cloud Image..."
        wget -q --show-progress -O "$CACHE_DIR/debian-12-generic-amd64.qcow2" "$DEBIAN12_URL"
        INSTALLED_COMPONENTS+=("Cached Debian 12 Image")
    fi

    # 3. Debian 13 (Trixie)
    echo ""
    if [ -f "$CACHE_DIR/debian-13-generic-amd64.qcow2" ]; then
        prompt_read "Debian 13 image is already cached. Re-download / overwrite? [y/N]: " DL_DEB13 "N"
    else
        prompt_read "Download Debian 13 (Trixie) Cloud Image? [y/N]: " DL_DEB13 "N"
    fi
    if [[ "$DL_DEB13" =~ ^[Yy]$ ]]; then
        echo "==> Downloading Debian 13 (Trixie) Cloud Image..."
        wget -q --show-progress -O "$CACHE_DIR/debian-13-generic-amd64.qcow2" "$DEBIAN13_URL"
        INSTALLED_COMPONENTS+=("Cached Debian 13 Image")
    fi
fi

# Safe BASH_SOURCE resolution for piped stdin vs local file execution
SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
LOCAL_HARNESS=""

if [ -n "$SCRIPT_SOURCE" ] && [ "$SCRIPT_SOURCE" != "-" ] && [ -f "$SCRIPT_SOURCE" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
    REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    if [ -f "$REPO_ROOT/bin/test-vm" ]; then
        LOCAL_HARNESS="$REPO_ROOT/bin/test-vm"
    fi
fi

echo ""
if [ -n "$LOCAL_HARNESS" ]; then
    chmod +x "$LOCAL_HARNESS"
    if [ -w /usr/local/bin ]; then
        cp "$LOCAL_HARNESS" /usr/local/bin/test-vm
    else
        sudo cp "$LOCAL_HARNESS" /usr/local/bin/test-vm
        sudo chmod +x /usr/local/bin/test-vm
    fi
    echo "✅ Installed 'test-vm' harness to /usr/local/bin/test-vm"
    INSTALLED_COMPONENTS+=("Installed test-vm CLI to /usr/local/bin")
else
    echo "==> Fetching latest 'test-vm' harness from GitHub..."
    if [ -w /usr/local/bin ]; then
        curl -fsSL https://raw.githubusercontent.com/notasandworm/install/feat-ability-qemu/bin/test-vm -o /usr/local/bin/test-vm
        chmod +x /usr/local/bin/test-vm
    else
        sudo curl -fsSL https://raw.githubusercontent.com/notasandworm/install/feat-ability-qemu/bin/test-vm -o /usr/local/bin/test-vm
        sudo chmod +x /usr/local/bin/test-vm
    fi
    echo "✅ Installed 'test-vm' harness to /usr/local/bin/test-vm"
    INSTALLED_COMPONENTS+=("Installed test-vm CLI to /usr/local/bin")
fi

echo ""
echo "=============================================================================="
echo "🎉 Arch Linux QEMU / KVM Provisioning Complete!"
echo "=============================================================================="
echo "Installed Components:"
for item in "${INSTALLED_COMPONENTS[@]}"; do
    echo "  - $item"
done

echo ""
echo "Usage:"
echo "  Run post-install script tests inside instant ephemeral KVM VMs:"
echo "    test-vm run --os arch --script bin/deb/dev.sh"
echo "    test-vm run --os debian12 --script bin/deb/hdi.sh"
echo "=============================================================================="
