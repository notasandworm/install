#!/usr/bin/env bash
set -euo pipefail

echo "=============================================================================="
echo "🧪 Running QEMU Test Harness Verification Suite"
echo "=============================================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FAILURES=0

run_test() {
    local test_name="$1"
    shift
    echo -n "Testing $test_name... "
    if "$@"; then
        echo "✅ PASS"
    else
        echo "❌ FAIL"
        FAILURES=$((FAILURES + 1))
    fi
}

run_url_test() {
    local test_name="$1"
    shift
    echo -n "Checking $test_name... "
    if "$@"; then
        echo "✅ ONLINE"
    else
        echo "⚠️  TIMEOUT / OFFLINE (Warning)"
    fi
}

# 1. Syntax Verification
echo ""
echo "--- 1. Script Syntax Verification (bash -n) ---"
run_test "bin/deb/kvm.sh syntax" bash -n "$REPO_ROOT/bin/deb/kvm.sh"
run_test "bin/arch/kvm.sh syntax" bash -n "$REPO_ROOT/bin/arch/kvm.sh"
run_test "bin/qemu-vm syntax" bash -n "$REPO_ROOT/bin/qemu-vm"

# 2. Cloud Image URL Reachability
echo ""
echo "--- 2. Cloud Image Mirror Reachability (HTTP 200/302) ---"

check_url() {
    local url="$1"
    local status
    status=$(curl -sI -m 10 "$url" 2>/dev/null | grep -i "^HTTP" | tail -n 1 | awk '{print $2}')
    if [ "$status" = "200" ] || [ "$status" = "301" ] || [ "$status" = "302" ]; then
        return 0
    else
        echo "(HTTP ${status:-000}) "
        return 1
    fi
}

run_url_test "Debian 12 (Bookworm) Cloud URL" check_url "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
run_url_test "Debian 13 (Trixie) Cloud URL" check_url "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
run_url_test "Arch Linux Basic Cloud URL" check_url "https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-basic.qcow2"

echo ""
echo "=============================================================================="
if [ $FAILURES -eq 0 ]; then
    echo "🎉 All verification tests passed successfully!"
    exit 0
else
    echo "❌ $FAILURES test(s) failed."
    exit 1
fi
