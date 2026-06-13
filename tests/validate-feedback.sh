#!/usr/bin/env bash
# Layer 1: Feedback-format sync guard.
# The mandatory feedback sections are defined once in shared/feedback-format.md and mirrored by
# the issue template (.github/ISSUE_TEMPLATE/feedback.md) and the CI check
# (.github/workflows/feedback-check.yml). This fails the build if the three drift apart:
#   1. the CI REQUIRED list must equal the canonical mandatory list, and
#   2. every canonical mandatory section must appear as a "## " heading in the issue template.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0

red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
error() { red "ERROR: $*"; ERRORS=$((ERRORS + 1)); }
ok()    { green "OK: $*"; }

FORMAT="$REPO_ROOT/shared/feedback-format.md"
TEMPLATE="$REPO_ROOT/.github/ISSUE_TEMPLATE/feedback.md"
WORKFLOW="$REPO_ROOT/.github/workflows/feedback-check.yml"

echo ""
echo "=== Checking feedback-format sync ==="

missing_file=0
for f in "$FORMAT" "$TEMPLATE" "$WORKFLOW"; do
    if [[ ! -f "$f" ]]; then
        error "missing required feedback file: ${f#"$REPO_ROOT"/}"
        missing_file=1
    fi
done
if [[ $missing_file -ne 0 ]]; then
    red "FAILED: $ERRORS error(s)"
    exit 1
fi

# Canonical mandatory list — shared/feedback-format.md, "- Heading" lines between the markers.
canonical="$(awk '/mandatory-sections:start/{f=1; next} /mandatory-sections:end/{f=0} f && /^- /{sub(/^- /,""); print}' "$FORMAT")"

# CI REQUIRED list — feedback-check.yml, quoted strings between the markers.
ci_required="$(awk '/mandatory-sections:start/{f=1; next} /mandatory-sections:end/{f=0} f' "$WORKFLOW" | grep -oE '"[^"]+"' | sed 's/"//g')"

# Issue-template headings — every "## " heading (mandatory + optional).
template_headings="$(grep -E '^## ' "$TEMPLATE" | sed 's/^## //')"

[[ -z "$canonical" ]]   && error "no mandatory-sections block found in shared/feedback-format.md"
[[ -z "$ci_required" ]] && error "no mandatory-sections block found in .github/workflows/feedback-check.yml"

# 1) Canonical list must equal the CI REQUIRED list (order-insensitive).
if [[ -n "$canonical" && -n "$ci_required" ]]; then
    if diff <(printf '%s\n' "$canonical" | sort) <(printf '%s\n' "$ci_required" | sort) >/dev/null; then
        ok "CI REQUIRED matches the canonical mandatory list"
    else
        error "CI REQUIRED (feedback-check.yml) differs from the canonical list (shared/feedback-format.md):"
        diff <(printf '%s\n' "$canonical" | sort) <(printf '%s\n' "$ci_required" | sort) || true
    fi
fi

# 2) Every canonical mandatory section must appear as a heading in the template.
if [[ -n "$canonical" && -n "$template_headings" ]]; then
    while IFS= read -r section; do
        [[ -z "$section" ]] && continue
        if printf '%s\n' "$template_headings" | grep -qxF "$section"; then
            ok "template has mandatory section: $section"
        else
            error "issue template is missing mandatory section: '$section'"
        fi
    done <<< "$canonical"
fi

echo ""
echo "============================"
if [[ $ERRORS -gt 0 ]]; then
    red "FAILED: $ERRORS error(s)"
    exit 1
else
    green "PASSED: feedback format in sync"
    exit 0
fi
