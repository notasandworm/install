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

echo "==> Setting up QEMU / KVM Virtualization & AI Agent Test Suite (Debian/Ubuntu)..."

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
prompt_read "Install QEMU/KVM package suite? [Y/n]: " INSTALL_PKGS_RESP "Y"

if [[ "$INSTALL_PKGS_RESP" =~ ^[Yy]$ ]]; then
    echo "==> Updating APT package index..."
    sudo apt-get update
    echo "==> Installing QEMU/KVM packages..."
    sudo apt-get install -y "${KVM_PKGS[@]}"
    INSTALLED_COMPONENTS+=("QEMU/KVM Core Packages")
fi

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

# Base Image Cache Setup
CACHE_DIR="${HOME}/.cache/qemu-test-images"
mkdir -p "$CACHE_DIR"

DEBIAN12_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
DEBIAN13_URL="https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-generic-amd64.qcow2"

echo ""
echo "Base Cloud Images Caching (~/.cache/qemu-test-images):"
echo "  - Debian 12 (Bookworm Generic Cloud)"
echo "  - Debian 13 (Trixie Generic Cloud)"

prompt_read "Pre-download baseline Debian QCOW2 cloud images now? [Y/n]: " DOWNLOAD_IMAGES_RESP "Y"

if [[ "$DOWNLOAD_IMAGES_RESP" =~ ^[Yy]$ ]]; then
    if [ ! -f "$CACHE_DIR/debian-12-generic-amd64.qcow2" ]; then
        echo "==> Fetching Debian 12 (Bookworm) Cloud Image..."
        wget -q --show-progress -O "$CACHE_DIR/debian-12-generic-amd64.qcow2" "$DEBIAN12_URL"
    else
        echo "✅ Debian 12 cloud image is already cached."
    fi

    if [ ! -f "$CACHE_DIR/debian-13-generic-amd64.qcow2" ]; then
        echo "==> Fetching Debian 13 (Trixie) Cloud Image..."
        wget -q --show-progress -O "$CACHE_DIR/debian-13-generic-amd64.qcow2" "$DEBIAN13_URL" || echo "⚠️ Daily build of Debian 13 temporary fetch issue; can be fetched on demand by test-vm script."
    else
        echo "✅ Debian 13 cloud image is already cached."
    fi
    INSTALLED_COMPONENTS+=("Cached Debian Cloud Base Images")
fi

# Helper Harness Installation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -f "$REPO_ROOT/bin/test-vm" ]; then
    chmod +x "$REPO_ROOT/bin/test-vm"
    if [ -w /usr/local/bin ]; then
        cp "$REPO_ROOT/bin/test-vm" /usr/local/bin/test-vm
        echo "✅ Installed 'test-vm' harness to /usr/local/bin/test-vm"
        INSTALLED_COMPONENTS+=("Installed test-vm CLI to /usr/local/bin")
    else
        if prompt_read "Install 'test-vm' harness to /usr/local/bin/test-vm via sudo? [Y/n]: " INSTALL_HARNESS_RESP "Y" && [[ "$INSTALL_HARNESS_RESP" =~ ^[Yy]$ ]]; then
            sudo cp "$REPO_ROOT/bin/test-vm" /usr/local/bin/test-vm
            sudo chmod +x /usr/local/bin/test-vm
            echo "✅ Installed 'test-vm' harness to /usr/local/bin/test-vm"
            INSTALLED_COMPONENTS+=("Installed test-vm CLI to /usr/local/bin")
        fi
    fi
fi

echo ""
echo "=============================================================================="
echo "🎉 QEMU / KVM Provisioning Complete!"
echo "=============================================================================="
echo "Installed Components:"
for item in "${INSTALLED_COMPONENTS[@]}"; do
    echo "  - $item"
done

echo ""
echo "Usage:"
echo "  Run post-install script tests inside instant ephemeral KVM VMs:"
echo "    test-vm run --os debian12 --script bin/deb/dev.sh"
echo "    test-vm run --os debian13 --script bin/deb/hdi.sh"
echo "    test-vm run --os arch --script bin/deb/vnc.sh"
echo "=============================================================================="
