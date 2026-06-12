#!/usr/bin/env bash
# CI orchestrator: runs all Layer 1 structural validation scripts
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_ERRORS=0

echo "================================================"
echo "  agentic-harness Structural Validation Suite"
echo "================================================"

run_test() {
    local script="$1"
    local name="$2"

    echo ""
    echo "--- Running: $name ---"

    if bash "$script"; then
        echo "--- $name: PASSED ---"
    else
        echo "--- $name: FAILED ---"
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
}

run_test "$TESTS_DIR/validate-plugin.sh" "Plugin Structure"
run_test "$TESTS_DIR/validate-references.sh" "Reference Paths"
run_test "$TESTS_DIR/validate-versions.sh" "Version Sync"

echo ""
echo "================================================"
if [[ $TOTAL_ERRORS -gt 0 ]]; then
    printf '\033[0;31m  %d test suite(s) failed\033[0m\n' "$TOTAL_ERRORS"
    exit 1
else
    printf '\033[0;32m  All test suites passed\033[0m\n'
    exit 0
fi
