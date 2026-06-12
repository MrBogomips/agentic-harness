#!/usr/bin/env bash
# Layer 1: Reference path validation (root-layout plugin)
# Checks that every references/ path mentioned in SKILL.md files resolves to an
# existing file, that every ${CLAUDE_PLUGIN_ROOT}/... path mentioned anywhere in
# the plugin resolves from the repo root, and that no broken relative links
# exist in root-level markdown files.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0
WARNINGS=0

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }

error() { red "ERROR: $*"; ERRORS=$((ERRORS + 1)); }
warn()  { yellow "WARN: $*"; WARNINGS=$((WARNINGS + 1)); }
ok()    { green "OK: $*"; }

# --- Skill-relative references ---

for skill_dir in "$REPO_ROOT"/skills/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    skill_md="$skill_dir/SKILL.md"

    [[ -f "$skill_md" ]] || continue

    echo ""
    echo "=== Checking references: skills/$skill_name ==="

    # Extract references/ paths from SKILL.md
    # Matches patterns like: references/workflow.md, `references/foo.md`, references/packs/en.md
    while IFS= read -r ref_path; do
        # Clean up the path (remove backticks, quotes, trailing punctuation)
        clean_path="$(echo "$ref_path" | sed 's/[`"'"'"']//g; s/[),;]$//')"

        # Skip paths that are clearly templated
        [[ "$clean_path" == *"{lang}"* ]] && continue
        [[ "$clean_path" == *"{LANG}"* ]] && continue

        # Resolve relative to skill directory
        full_path="$skill_dir/$clean_path"

        if [[ -f "$full_path" ]]; then
            ok "skills/$skill_name: $clean_path exists"
        else
            error "skills/$skill_name: broken reference '$clean_path' (resolved to $full_path)"
        fi
    done < <(grep -oE 'references/[a-zA-Z0-9_./-]+\.[a-z]+' "$skill_md" | sort -u || true)

    # Check for references to assets/ and scripts/ paths
    while IFS= read -r asset_path; do
        clean_path="$(echo "$asset_path" | sed 's/[`"'"'"']//g; s/[),;]$//')"
        full_path="$skill_dir/$clean_path"

        if [[ -f "$full_path" ]]; then
            ok "skills/$skill_name: $clean_path exists"
        else
            # Only warn for assets/scripts since they may use <skill-dir> placeholder
            warn "skills/$skill_name: asset/script reference '$clean_path' not found at $full_path"
        fi
    done < <(grep -oE '(assets|scripts)/[a-zA-Z0-9_./-]+\.[a-z]+' "$skill_md" | sort -u || true)
done

# --- ${CLAUDE_PLUGIN_ROOT}/... paths (the plugin's main internal linkage) ---

echo ""
echo "=== Checking \${CLAUDE_PLUGIN_ROOT} paths ==="

while IFS= read -r plugin_root_ref; do
    rel_path="${plugin_root_ref#\$\{CLAUDE_PLUGIN_ROOT\}/}"
    if [[ -f "$REPO_ROOT/$rel_path" ]]; then
        ok "\${CLAUDE_PLUGIN_ROOT}/$rel_path exists"
    else
        error "broken plugin-root reference '\${CLAUDE_PLUGIN_ROOT}/$rel_path' (resolved to $REPO_ROOT/$rel_path)"
    fi
done < <(grep -rhoE '\$\{CLAUDE_PLUGIN_ROOT\}/[a-zA-Z0-9_./-]+\.[a-z]+' "$REPO_ROOT/skills" "$REPO_ROOT/shared" 2>/dev/null | sort -u || true)

# --- Markdown links in root-level files (README.md, etc.) ---

echo ""
echo "=== Checking root markdown links ==="

for md_file in "$REPO_ROOT"/*.md; do
    [[ -f "$md_file" ]] || continue
    md_name="$(basename "$md_file")"

    while IFS= read -r link_target; do
        # Skip URLs
        [[ "$link_target" == http* ]] && continue
        # Skip anchors
        [[ "$link_target" == \#* ]] && continue

        # Resolve relative to repo root
        full_path="$REPO_ROOT/$link_target"
        if [[ ! -f "$full_path" && ! -d "$full_path" ]]; then
            warn "$md_name: broken link '$link_target'"
        fi
    done < <(sed -n 's/.*\[.*\](\([^)]*\)).*/\1/p' "$md_file" 2>/dev/null || true)
done

# Summary
echo ""
echo "============================"
if [[ $ERRORS -gt 0 ]]; then
    red "FAILED: $ERRORS error(s), $WARNINGS warning(s)"
    exit 1
elif [[ $WARNINGS -gt 0 ]]; then
    yellow "PASSED with $WARNINGS warning(s)"
    exit 0
else
    green "PASSED: all references valid"
    exit 0
fi
