#!/usr/bin/env bash
# Integration test runner using qemu-vm to test scripts headlessly
set -euo pipefail

OS_TARGET="debian12"
TEST_MODULE=""
BRANCH_TARGET=""
RUN_ALL=false
TEST_MODE="local" # "local" or "remote"

# Auto-detect current git branch
CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || echo "main")"
BRANCH_TARGET="${CURRENT_BRANCH}"

usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --os <distro>      Target guest OS (default: debian12, choices: debian12, debian13, arch)"
    echo "  --module <name>    Run integration test on a specific module (choices: dev, hdi, vnc, hardening, kvm)"
    echo "  --branch <branch>  Target branch for remote testing (default: current branch '$CURRENT_BRANCH')"
    echo "  --mode <type>      Test mode: 'local' (uses files in workspace) or 'remote' (uses GitHub URLs) (default: local)"
    echo "  --all              Run all test modules sequentially"
    echo "  -h, --help         Show this help message"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --os)
            OS_TARGET="$2"
            shift 2
            ;;
        --module)
            TEST_MODULE="$2"
            shift 2
            ;;
        --branch)
            BRANCH_TARGET="$2"
            shift 2
            ;;
        --mode)
            TEST_MODE="$2"
            shift 2
            ;;
        --all)
            RUN_ALL=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            ;;
    esac
done

if [ "$RUN_ALL" = false ] && [ -z "$TEST_MODULE" ]; then
    echo "Error: Must specify --module <name> or --all."
    usage
fi

ALL_MODULES=(kvm dev hdi vnc hardening)

# Translate simple module names to script paths
get_script_path() {
    local mod="$1"
    if [ "$mod" = "kvm" ]; then
        if [ "$OS_TARGET" = "arch" ]; then
            echo "bin/arch/kvm.sh"
        else
            echo "bin/deb/kvm.sh"
        fi
    else
        echo "bin/deb/${mod}.sh"
    fi
}

run_module_test() {
    local mod="$1"
    local script_rel
    script_rel=$(get_script_path "$mod")

    echo "=============================================================================="
    echo "🧪 RUNNING INTEGRATION TEST FOR: $mod (OS: $OS_TARGET, Mode: $TEST_MODE)"
    echo "=============================================================================="

    if [ "$TEST_MODE" = "local" ]; then
        if [ ! -f "$script_rel" ]; then
            echo "❌ Error: Local script file '$script_rel' not found!"
            return 1
        fi
        echo "Running local script: $script_rel"
        ./bin/qemu-vm run --os "$OS_TARGET" --script "$script_rel" --args "-y"
    else
        local remote_url="https://raw.githubusercontent.com/notasandworm/install/${BRANCH_TARGET}/${script_rel}"
        echo "Running remote URL script: $remote_url"
        ./bin/qemu-vm run --os "$OS_TARGET" --url "$remote_url" --args "-y"
    fi
}

# Run tests
FAILED=0
if [ "$RUN_ALL" = true ]; then
    echo "Starting integration test suite run..."
    for mod in "${ALL_MODULES[@]}"; do
        if ! run_module_test "$mod"; then
            echo "❌ MODULE '$mod' FAILED!"
            FAILED=$((FAILED + 1))
        else
            echo "✅ MODULE '$mod' PASSED!"
        fi
    done
else
    if ! run_module_test "$TEST_MODULE"; then
        echo "❌ MODULE '$TEST_MODULE' FAILED!"
        FAILED=1
    else
        echo "✅ MODULE '$TEST_MODULE' PASSED!"
    fi
fi

if [ $FAILED -gt 0 ]; then
    echo "------------------------------------------------------------------------------"
    echo "❌ INTEGRATION TESTS COMPLETE: $FAILED FAILURE(S) DETECTED."
    exit 1
else
    echo "------------------------------------------------------------------------------"
    echo "✅ ALL INTEGRATION TESTS PASSED SUCCESSFULLY!"
    exit 0
fi
