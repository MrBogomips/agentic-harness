#!/usr/bin/env bash
# check-generated.sh — read-only lint of a generated harness in a target project.
#
# Usage: check-generated.sh [PROJECT_DIR]   (defaults to the current directory)
#
# Checks the mechanical items of harness-setup's deliverable checklist:
#   1. no unsubstituted template placeholder in .claude/agents, .claude/skills, or CLAUDE.md
#   2. no ${CLAUDE_PLUGIN_ROOT} reference — generated files must be self-contained
#   3. every agent file and SKILL.md opens with frontmatter carrying `name:` and `description:`
#   4. no .claude/commands/ directory (the harness generates skills, not commands)
#   5. no copied CLI flag (--word) in a generated {domain}-visuals skill
#
# Output: one `ERROR: file:line: message` per violation, then a summary. Exit 0 when clean,
# 1 on any violation, 2 on bad usage. Writes nothing.
set -euo pipefail

PROJECT="${1:-.}"
[ -d "$PROJECT" ] || { echo "usage: check-generated.sh [PROJECT_DIR]" >&2; exit 2; }
PROJECT="$(cd "$PROJECT" && pwd)"
ERRORS=0

error() { echo "ERROR: $*"; ERRORS=$((ERRORS + 1)); }

# Placeholder shapes the harness-setup templates use:
#   {UPPER_SLOT} or {UPPER_SLOT: hint}     {YYYY-MM-DD}
#   {domain}-style single-word slots (named, so runtime tokens like {id} stay legal)
#   {prose slot, with a hint}  {user's target path}  {on|off}  {…}
# {YYYYMMDD_HHMMSS} is a runtime naming pattern inside the orchestrator, not a slot, and
# shell brace expansion such as {spec,plan,tasks}.md has no space, so neither is flagged.
UPPER_TOKEN='\{[A-Z][A-Z0-9_-]*(\}|:)'
ALLOWED_UPPER='\{YYYYMMDD_HHMMSS\}'
NAMED_TOKEN='\{(domain|Domain|deliverable|audience|artifact|contract|date|input|member|members|member-[0-9]+|path|phase|skill|system|tracker|version|orchestrator-skill-name)\}'
PROSE_TOKEN="\\{[A-Za-z][A-Za-z-]*( |, |'|\\|)|\\{…\\}"
# CLAUDE.md also holds the user's own text, so only the pointer template's slots are checked there.
POINTER_TOKEN='\{(YYYY-MM-DD|one line on|ready-work query|write-back convention|owned segment)'
PLUGIN_ROOT_REF='\$\{CLAUDE_PLUGIN_ROOT\}'
FLAG='(^|[[:space:]`(])--[a-zA-Z]'

# Print "line:text" for lines of $1 matching extended regex $2, minus lines matching $3.
matches() {
    local file="$1" pattern="$2" except="${3:-}"
    if [ -n "$except" ]; then
        grep -nE "$pattern" "$file" | grep -vE "$except" || true
    else
        grep -nE "$pattern" "$file" || true
    fi
}

report() {
    local file="$1" message="$2" hits="$3" line
    [ -z "$hits" ] && return 0
    while IFS= read -r line; do
        error "${file#"$PROJECT"/}:${line%%:*}: $message"
    done <<EOF
$hits
EOF
}

check_placeholders() {
    local f="$1"
    # Strip allowed runtime patterns before looking for upper-case tokens.
    report "$f" "unsubstituted placeholder" \
        "$(grep -nE "$UPPER_TOKEN" "$f" | sed -E -e "s/$ALLOWED_UPPER//g" -e "s/$PLUGIN_ROOT_REF//g" | grep -E "^[0-9]+:.*$UPPER_TOKEN" || true)"
    report "$f" "unsubstituted placeholder" "$(matches "$f" "$NAMED_TOKEN|$PROSE_TOKEN")"
    report "$f" "\${CLAUDE_PLUGIN_ROOT} reference (generated files must be self-contained)" \
        "$(matches "$f" "$PLUGIN_ROOT_REF")"
}

check_frontmatter() {
    local f="$1" front
    if [ "$(head -n 1 "$f")" != "---" ]; then
        error "${f#"$PROJECT"/}:1: missing frontmatter"
        return 0
    fi
    front="$(awk 'NR > 1 && /^---[[:space:]]*$/ {exit} NR > 1 {print}' "$f")"
    printf '%s\n' "$front" | grep -qE '^name:[[:space:]]*[^[:space:]]' \
        || error "${f#"$PROJECT"/}:1: frontmatter has no name"
    printf '%s\n' "$front" | grep -qE '^description:[[:space:]]*[^[:space:]]' \
        || error "${f#"$PROJECT"/}:1: frontmatter has no description"
}

FILES=0
while IFS= read -r f; do
    [ -n "$f" ] || continue
    FILES=$((FILES + 1))
    check_placeholders "$f"
    case "$f" in
        */.claude/agents/*.md|*/SKILL.md) check_frontmatter "$f" ;;
    esac
    case "$f" in
        */.claude/skills/*-visuals/SKILL.md)
            report "$f" "copied CLI flag (defer to the tool's own help instead)" "$(matches "$f" "$FLAG")" ;;
    esac
done <<EOF
$(find "$PROJECT/.claude/agents" "$PROJECT/.claude/skills" -type f -name '*.md' 2>/dev/null | sort)
EOF

if [ -f "$PROJECT/CLAUDE.md" ]; then
    report "$PROJECT/CLAUDE.md" "unsubstituted placeholder" \
        "$(matches "$PROJECT/CLAUDE.md" "$NAMED_TOKEN|$POINTER_TOKEN")"
fi

if [ -d "$PROJECT/.claude/commands" ]; then
    error ".claude/commands/: a harness generates skills, not commands"
fi

if [ "$ERRORS" -gt 0 ]; then
    echo "FAILED: $ERRORS problem(s) in $FILES generated file(s)"
    exit 1
fi
echo "OK: $FILES generated file(s) checked, no problems"
