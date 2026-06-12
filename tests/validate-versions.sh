#!/usr/bin/env bash
# Layer 1: Plugin/marketplace version sync validation (single-plugin repo)
# Checks that plugin.json and the marketplace.json entry agree on name and version.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_JSON="$REPO_ROOT/.claude-plugin/plugin.json"
MANIFEST="$REPO_ROOT/.claude-plugin/marketplace.json"
ERRORS=0

red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }

error() { red "ERROR: $*"; ERRORS=$((ERRORS + 1)); }
ok()    { green "OK: $*"; }

if ! command -v jq >/dev/null 2>&1; then
    error "jq is required but not installed"
    red "FAILED: $ERRORS error(s)"
    exit 1
fi

for f in "$PLUGIN_JSON" "$MANIFEST"; do
    if [[ ! -f "$f" ]]; then
        error "missing $f"
    elif ! jq empty "$f" 2>/dev/null; then
        error "$f is not valid JSON"
    fi
done
if [[ $ERRORS -gt 0 ]]; then
    red "FAILED: $ERRORS error(s)"
    exit 1
fi

entry_count="$(jq '.plugins | length' "$MANIFEST")"
if [[ "$entry_count" -ne 1 ]]; then
    error "marketplace.json: expected exactly 1 plugin entry, found $entry_count"
fi

pname="$(jq -r '.name // empty' "$PLUGIN_JSON")"
pver="$(jq -r '.version // empty' "$PLUGIN_JSON")"
mname="$(jq -r '.plugins[0].name // empty' "$MANIFEST")"
mver="$(jq -r '.plugins[0].version // empty' "$MANIFEST")"

if [[ -z "$pname" ]]; then
    error "plugin.json has no name"
fi
if [[ -z "$pver" ]]; then
    error "plugin.json has no version"
fi

if [[ -n "$pname" && "$pname" != "$mname" ]]; then
    error "name drift — plugin.json='$pname', marketplace.json='$mname'"
fi

if [[ -n "$pver" && "$pver" != "$mver" ]]; then
    error "$pname: version drift — plugin.json=$pver, marketplace.json=$mver"
elif [[ -n "$pver" ]]; then
    ok "$pname: version $pver in sync"
fi

# Summary
echo ""
echo "============================"
if [[ $ERRORS -gt 0 ]]; then
    red "FAILED: $ERRORS error(s)"
    exit 1
else
    green "PASSED: plugin version in sync with marketplace.json"
    exit 0
fi
