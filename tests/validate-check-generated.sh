#!/usr/bin/env bash
# Layer 1: behavioural test for skills/harness-setup/scripts/check-generated.sh
# - the clean fixture passes and the broken fixture fails on every planted problem;
# - every placeholder slot used in the generation templates is caught (so a new template
#   slot cannot silently escape the check), while runtime tokens stay legal.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/skills/harness-setup/scripts/check-generated.sh"
FIXTURE="$REPO_ROOT/tests/fixtures/generated"
REFS="$REPO_ROOT/skills/harness-setup/references"
ERRORS=0

red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
pass()  { green "PASS: $*"; }
fail()  { red "FAIL: $*"; ERRORS=$((ERRORS + 1)); }

[ -x "$SCRIPT" ] || { red "FAIL: $SCRIPT missing or not executable"; exit 1; }

if out="$(bash "$SCRIPT" "$FIXTURE/good")"; then
    pass "clean fixture passes"
else
    fail "clean fixture reported problems:"; printf '%s\n' "$out"
fi

out="$(bash "$SCRIPT" "$FIXTURE/bad" || true)"
for expect in \
    "writer.md:1: frontmatter has no description" \
    "writer.md:6: unsubstituted placeholder" \
    "writer.md:7: unsubstituted placeholder" \
    "docs-orchestrator/SKILL.md:2: unsubstituted placeholder" \
    "docs-orchestrator/SKILL.md:8: unsubstituted placeholder" \
    "docs-orchestrator/SKILL.md:10: \${CLAUDE_PLUGIN_ROOT} reference" \
    "docs-visuals/SKILL.md:6: copied CLI flag" \
    "CLAUDE.md:1: unsubstituted placeholder" \
    "CLAUDE.md:2: unsubstituted placeholder" \
    ".claude/commands/"; do
    if printf '%s\n' "$out" | grep -qF "$expect"; then
        pass "broken fixture: $expect"
    else
        fail "broken fixture: expected '$expect'"
    fi
done

# Every slot in the templates' generated blocks must be caught.
TMP="$(mktemp -d "${TMPDIR:-/tmp}/check-generated.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
tokens="$(for f in orchestrator-template.md agent-design-patterns.md visual-skill-template.md \
                 setup-check-template.md tracker-sync-template.md; do
    awk '/^````?markdown[[:space:]]*$/ {inb=1; next} /^````?[[:space:]]*$/ {inb=0; next} inb {print}' "$REFS/$f"
done | grep -oE '\{[^{}"]+\}' | sort -u | grep -vxF '{YYYYMMDD_HHMMSS}')"
missed=0
while IFS= read -r token; do
    [ -n "$token" ] || continue
    mkdir -p "$TMP/p/.claude/skills/s"
    printf -- '---\nname: s\ndescription: "d"\n---\n\nslot %s here\n' "$token" > "$TMP/p/.claude/skills/s/SKILL.md"
    if bash "$SCRIPT" "$TMP/p" >/dev/null; then
        fail "template slot not caught: $token"; missed=$((missed + 1))
    fi
done <<LIST
$tokens
LIST
[ "$missed" -eq 0 ] && pass "all $(printf '%s\n' "$tokens" | grep -c .) template slots are caught"

# Runtime tokens that generated orchestrators legitimately keep.
printf -- '---\nname: s\ndescription: "d"\n---\n\n`_agents_workspace/archive/{YYYYMMDD_HHMMSS}/` `bd close {id}` `specs/<NNN>/{spec,plan,tasks}.md`\n' \
    > "$TMP/p/.claude/skills/s/SKILL.md"
if bash "$SCRIPT" "$TMP/p" >/dev/null; then
    pass "runtime tokens stay legal"
else
    fail "runtime tokens were flagged"
fi

if [ "$ERRORS" -gt 0 ]; then
    red "FAILED: $ERRORS error(s)"
    exit 1
fi
green "Generated-harness checker passed"
