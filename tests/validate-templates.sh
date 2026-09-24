#!/usr/bin/env bash
# Layer 1: Generated-skill template lint.
# The generated {domain}-visuals and {domain}-setup-check skills must be self-contained and must
# record choices, not copy tool instructions: inside each template's generated block (the
# ````markdown fence) there must be no ${CLAUDE_PLUGIN_ROOT} reference and no CLI flag (--word).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REFS="$REPO_ROOT/skills/harness-setup/references"
TEMPLATES="visual-skill-template.md setup-check-template.md"
ERRORS=0

red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }

error() { red "ERROR: $*"; ERRORS=$((ERRORS + 1)); }
ok()    { green "OK: $*"; }

# Print the lines inside the ````markdown ... ```` fence, prefixed with their line number.
generated_block() {
    awk '/^````markdown[[:space:]]*$/ {inb=1; next} /^````[[:space:]]*$/ {inb=0; next} inb {print NR": "$0}' "$1"
}

for t in $TEMPLATES; do
    f="$REFS/$t"
    if [[ ! -f "$f" ]]; then
        error "$t: missing"
        continue
    fi
    block="$(generated_block "$f")"
    if [[ -z "$block" ]]; then
        error "$t: no \`\`\`\`markdown generated block found"
        continue
    fi
    hits="$(printf '%s\n' "$block" | grep -F '${CLAUDE_PLUGIN_ROOT}' || true)"
    if [[ -n "$hits" ]]; then
        error "$t: generated block references \${CLAUDE_PLUGIN_ROOT} (must be self-contained):"
        printf '%s\n' "$hits"
    fi
    hits="$(printf '%s\n' "$block" | grep -E '(^|[[:space:]`(])--[a-zA-Z]' || true)"
    if [[ -n "$hits" ]]; then
        error "$t: generated block copies a CLI flag (defer to the tool's own help instead):"
        printf '%s\n' "$hits"
    fi
    if [[ "$ERRORS" -eq 0 ]]; then
        ok "$t: generated block is self-contained and flag-free"
    fi
done

if [[ "$ERRORS" -gt 0 ]]; then
    red "FAILED: $ERRORS error(s)"
    exit 1
fi
green "Template lint passed"
