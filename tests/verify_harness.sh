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

# 1. Syntax Verification
echo ""
echo "--- 1. Script Syntax Verification (bash -n) ---"
run_test "bin/deb/kvm.sh syntax" bash -n "$REPO_ROOT/bin/deb/kvm.sh"
run_test "bin/arch/kvm.sh syntax" bash -n "$REPO_ROOT/bin/arch/kvm.sh"
run_test "bin/test-vm syntax" bash -n "$REPO_ROOT/bin/test-vm"

# 2. Piped Execution BASH_SOURCE Check
echo ""
echo "--- 2. Piped Execution (BASH_SOURCE) Simulation ---"
run_test "bin/deb/kvm.sh piped stdin prompt check" bash -c "printf 'n\n' | bash '$REPO_ROOT/bin/deb/kvm.sh' >/dev/null"
run_test "bin/arch/kvm.sh piped stdin prompt check" bash -c "printf 'n\n' | bash '$REPO_ROOT/bin/arch/kvm.sh' >/dev/null"
run_test "bin/deb/kvm.sh stdin curl pipe check" bash -c "printf 'n\n' | bash <(cat '$REPO_ROOT/bin/deb/kvm.sh') >/dev/null"

# 3. Cloud Image URL Reachability
echo ""
echo "--- 3. Cloud Image Mirror Reachability (HTTP 200/302) ---"

check_url() {
    local url="$1"
    local status
    status=$(curl -sI -m 10 -o /dev/null -w "%{http_code}" "$url" || echo "000")
    if [[ "$status" =~ ^(200|301|302)$ ]]; then
        return 0
    else
        echo "(HTTP $status) "
        return 1
    fi
}

run_test "Debian 12 (Bookworm) Cloud URL" check_url "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
run_test "Debian 13 (Trixie) Cloud URL" check_url "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
run_test "Arch Linux Basic Cloud URL" check_url "https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-basic.qcow2"

echo ""
echo "=============================================================================="
if [ $FAILURES -eq 0 ]; then
    echo "🎉 All verification tests passed successfully!"
    exit 0
else
    echo "❌ $FAILURES test(s) failed."
    exit 1
fi
