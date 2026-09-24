#!/usr/bin/env bash
# check-system.sh — read-only detection of the tools a harness depends on.
#
# Usage: check-system.sh [--project DIR] [TOOLS_FILE]   (TOOLS_FILE defaults to stdin)
#
# Input: one tool per line, `tool|probe[+probe...]`; `#` comments and blank lines
# are ignored. Probe kinds:
#   plugin:<name@marketplace> | plugin:<name>   Claude Code plugin
#   skill:<name>                                skill (user, project, synced, ~/.agents, plugin)
#   mcp:<name>                                  MCP server (names only — never values)
#   cli:<cmd>                                   executable on PATH
#   env:<VAR>                                   environment variable is set (value never printed)
#   remote:<name>                               claude.ai connector (not checkable from files)
#
# Output (stdout, TSV): header `tool probe status detail`, one row per probe, then one
# rollup row per input line with probe `*` carrying the worst status of its probes.
# Status order, worst -> best:
#   cannot-check, missing, broken-link, stale, disabled, disabled-here, unknown-remote, ok
#
# Locations: config root CFG=${CLAUDE_CONFIG_DIR:-$HOME/.claude}. The global claude.json is
# $CLAUDE_CONFIG_DIR/.claude.json when CLAUDE_CONFIG_DIR is set, else $HOME/.claude.json
# (the two layouts Claude Code uses; no further guessing).
#
# Plugins: primary source is `claude plugin list --json` (run once). Without the `claude`
# CLI the script falls back to installed_plugins.json + enabledPlugins in settings files
# and marks details "(degraded)". jq is required for plugin/mcp probes (else cannot-check).
#
# Guarantees: never writes files; never prints env values or MCP env/args/headers.
# Exit: 0 on a completed run (whatever the statuses), 2 on usage error, 3 on an
# unsupported platform (only Darwin and Linux, including WSL).
# Portability: bash 3.2 / BSD userland compatible.
set -uo pipefail

readonly STATUS_ORDER="cannot-check missing broken-link stale disabled disabled-here unknown-remote ok"
readonly NAME_RE='^[A-Za-z0-9@._/-]+$'

usage() {
    echo "Usage: $(basename "$0") [--project DIR] [TOOLS_FILE]" >&2
    echo "  TOOLS_FILE lines: tool|kind:name[+kind:name...]  (stdin if omitted)" >&2
}

die_usage() { echo "check-system: $*" >&2; usage; exit 2; }

# ---------- argument parsing ----------
PROJECT_DIR="$PWD"
TOOLS_FILE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --project)
            [ $# -ge 2 ] || die_usage "--project needs a directory"
            PROJECT_DIR="$2"; shift 2 ;;
        --project=*) PROJECT_DIR="${1#--project=}"; shift ;;
        -h|--help) usage; exit 0 ;;
        -) TOOLS_FILE="-"; shift ;;
        -*) die_usage "unknown option: $1" ;;
        *)
            [ -z "$TOOLS_FILE" ] || die_usage "only one TOOLS_FILE allowed"
            TOOLS_FILE="$1"; shift ;;
    esac
done
[ -d "$PROJECT_DIR" ] || die_usage "project directory not found: $PROJECT_DIR"
if [ -n "$TOOLS_FILE" ] && [ "$TOOLS_FILE" != "-" ] && [ ! -r "$TOOLS_FILE" ]; then
    die_usage "cannot read tools file: $TOOLS_FILE"
fi

case "$(uname -s 2>/dev/null)" in
    Darwin|Linux) ;;
    *) echo "check-system: unsupported platform '$(uname -s 2>/dev/null)' (Darwin/Linux only)" >&2; exit 3 ;;
esac

# ---------- environment ----------
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    CLAUDE_JSON="$CLAUDE_CONFIG_DIR/.claude.json"
else
    CLAUDE_JSON="$HOME/.claude.json"
fi
PROJECT_LOGICAL="$(cd "$PROJECT_DIR" && pwd)"
PROJECT_PHYSICAL="$(cd "$PROJECT_DIR" && pwd -P)"
HAVE_JQ=0; command -v jq >/dev/null 2>&1 && HAVE_JQ=1
TAB="$(printf '\t')"
# Plugin rows are split on the ASCII unit separator: unlike TAB it is not IFS
# whitespace, so empty fields (e.g. missing version/scope) are preserved by `read`.
US="$(printf '\037')"

tilde() { case "$1" in "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }

rank() {
    local i=0 s
    for s in $STATUS_ORDER; do
        [ "$s" = "$1" ] && { echo "$i"; return; }
        i=$((i + 1))
    done
    echo 0
}

emit() { # tool probe status detail — strips tabs/newlines from fields
    local d
    d="$(printf '%s' "$4" | tr '\t\n' '  ')"
    printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$d"
}

same_project() { # $1 = projectPath from plugin data
    [ -n "$1" ] || return 1
    [ "$1" = "$PROJECT_LOGICAL" ] || [ "$1" = "$PROJECT_PHYSICAL" ] && return 0
    [ -d "$1" ] && [ "$(cd "$1" && pwd -P)" = "$PROJECT_PHYSICAL" ]
}

# ---------- plugin inventory (loaded once) ----------
# PLUGIN_ROWS: id<US>version<US>scope<US>enabled<US>installPath<US>projectPath
PLUGIN_SRC="none"; PLUGIN_ROWS=""; BLOCKLIST=""
load_plugins_cli() {
    local raw
    command -v claude >/dev/null 2>&1 || return 1
    raw="$(claude plugin list --json 2>/dev/null)" || return 1
    PLUGIN_ROWS="$(printf '%s' "$raw" | jq -r '.[] | [.id, (.version // ""), (.scope // ""),
        (.enabled | tostring), (.installPath // ""), (.projectPath // "")] | map(tostring) | join("\u001f")' 2>/dev/null)" || return 1
    PLUGIN_SRC="cli"
}
load_plugins_files() {
    local inst="$CFG/plugins/installed_plugins.json" s enabled="{}" f
    [ -f "$inst" ] || { PLUGIN_SRC="files"; return 0; }
    for f in "$CFG/settings.json" "$PROJECT_PHYSICAL/.claude/settings.json" "$PROJECT_PHYSICAL/.claude/settings.local.json"; do
        [ -f "$f" ] || continue
        s="$(jq -c '.enabledPlugins // {}' "$f" 2>/dev/null)" || continue
        enabled="$(jq -cn --argjson a "$enabled" --argjson b "$s" '$a + $b')"
    done
    PLUGIN_ROWS="$(jq -r --argjson en "$enabled" '.plugins // {} | to_entries[] | .key as $id | .value[]? |
        [$id, (.version // ""), (.scope // ""), (($en[$id] // false) | tostring),
         (.installPath // ""), (.projectPath // "")] | map(tostring) | join("\u001f")' "$inst" 2>/dev/null)"
    PLUGIN_SRC="files"
}
load_plugins() {
    [ "$HAVE_JQ" = 1 ] || return 0
    load_plugins_cli || load_plugins_files
    [ -f "$CFG/plugins/blocklist.json" ] &&
        BLOCKLIST="$(jq -r '.plugins[]?.plugin // empty' "$CFG/plugins/blocklist.json" 2>/dev/null)"
    return 0
}

id_matches() { [ "$1" = "$2" ] || { case "$2" in *@*) return 1 ;; esac; [ "${1%%@*}" = "$2" ]; }; }

plugin_row_status() { # enabled scope installPath projectPath -> status
    [ "$1" = "true" ] || { echo disabled; return; }
    case "$2" in project|local) same_project "$4" || { echo disabled-here; return; } ;; esac
    [ -d "$3" ] || { echo stale; return; }
    echo ok
}

# Enabled plugins usable here: installPath<newline>...
enabled_plugin_paths() {
    local id ver scope en path proj
    [ -n "$PLUGIN_ROWS" ] || return 0
    while IFS="$US" read -r id ver scope en path proj; do
        [ "$(plugin_row_status "$en" "$scope" "$path" "$proj")" = ok ] && printf '%s\n' "$path"
    done <<< "$PLUGIN_ROWS"
}

probe_plugin() { # name -> "status<TAB>detail"
    local want="$1" id ver scope en path proj st best="missing" detail="not installed" b hit=""
    if [ "$PLUGIN_SRC" = none ]; then printf 'cannot-check\tjq not found\n'; return; fi
    if [ -n "$PLUGIN_ROWS" ]; then
        while IFS="$US" read -r id ver scope en path proj; do
            id_matches "$id" "$want" || continue
            st="$(plugin_row_status "$en" "$scope" "$path" "$proj")"
            if [ "$(rank "$st")" -gt "$(rank "$best")" ] || [ "$detail" = "not installed" ]; then
                best="$st"; hit="$id"
                case "$st" in
                    ok) detail="$id ${ver:-unversioned} (${scope:-scope unknown})" ;;
                    disabled) detail="$id installed but disabled ($scope)" ;;
                    disabled-here) detail="$id enabled for another project ($(tilde "$proj"))" ;;
                    stale) detail="$id installPath missing: $(tilde "$path")" ;;
                esac
            fi
        done <<< "$PLUGIN_ROWS"
    fi
    # Blocklist: compare the resolved id when installed, else the requested name.
    for b in $BLOCKLIST; do
        if { [ -n "$hit" ] && [ "$b" = "$hit" ]; } || { [ -z "$hit" ] && id_matches "$b" "$want"; }; then
            detail="$detail; BLOCKLISTED"; break
        fi
    done
    [ "$PLUGIN_SRC" = files ] && detail="$detail (degraded)"
    printf '%s\t%s\n' "$best" "$detail"
}

# ---------- skills ----------
skill_candidates() { # name -> "label<TAB>dir" lines, in priority order
    local n="$1" d p
    printf 'user\t%s\n' "$CFG/skills/$n"
    printf 'project\t%s\n' "$PROJECT_PHYSICAL/.claude/skills/$n"
    for d in "$CFG"/skills/synced/*/; do
        [ -d "$d" ] && printf 'synced\t%s\n' "${d%/}/$n"
    done
    printf 'agents\t%s\n' "$HOME/.agents/skills/$n"
    enabled_plugin_paths | while IFS= read -r p; do
        [ -n "$p" ] && printf 'plugin\t%s\n' "$p/skills/$n"
    done
}

in_skill_lock() {
    [ "$HAVE_JQ" = 1 ] && [ -f "$HOME/.agents/.skill-lock.json" ] &&
        jq -e --arg n "$1" '.skills[$n] != null' "$HOME/.agents/.skill-lock.json" >/dev/null 2>&1
}

probe_skill() {
    local n="$1" label dir broken="" note=""
    while IFS="$TAB" read -r label dir; do
        if [ -L "$dir" ] && [ ! -e "$dir" ]; then broken="${broken:-$(tilde "$dir")}"; continue; fi
        if [ -L "$dir/SKILL.md" ] && [ ! -e "$dir/SKILL.md" ]; then broken="${broken:-$(tilde "$dir/SKILL.md")}"; continue; fi
        if [ -f "$dir/SKILL.md" ]; then
            in_skill_lock "$n" && note=", via skill-lock"
            printf 'ok\t%s: %s%s\n' "$label" "$(tilde "$dir")" "$note"
            return
        fi
    done <<< "$(skill_candidates "$n")"
    if [ -n "$broken" ]; then printf 'broken-link\tsymlink target missing: %s\n' "$broken"; return; fi
    printf 'missing\tno SKILL.md found\n'
}

# ---------- MCP servers (names only) ----------
MCP_NAMES="" # label<TAB>name lines
MCP_KEYS_JQ='if (.mcpServers | type) == "object" then .mcpServers | keys[]
             elif type == "object" then keys[] else empty end'
load_mcp() {
    local p lines
    [ "$HAVE_JQ" = 1 ] || return 0
    if [ -f "$CLAUDE_JSON" ]; then
        lines="$(jq -r '.mcpServers // {} | keys[]' "$CLAUDE_JSON" 2>/dev/null | sed 's/^/user	/')"
        MCP_NAMES="$MCP_NAMES$lines"$'\n'
        lines="$(jq -r --arg a "$PROJECT_LOGICAL" --arg b "$PROJECT_PHYSICAL" \
            '[.projects[$a].mcpServers, .projects[$b].mcpServers] | map(. // {} | keys[]) | .[]' \
            "$CLAUDE_JSON" 2>/dev/null | sed 's/^/local	/')"
        MCP_NAMES="$MCP_NAMES$lines"$'\n'
    fi
    if [ -f "$PROJECT_PHYSICAL/.mcp.json" ]; then
        lines="$(jq -r '.mcpServers // {} | keys[]' "$PROJECT_PHYSICAL/.mcp.json" 2>/dev/null | sed 's/^/project	/')"
        MCP_NAMES="$MCP_NAMES$lines"$'\n'
    fi
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        [ -f "$p/.mcp.json" ] &&
            MCP_NAMES="$MCP_NAMES$(jq -r "$MCP_KEYS_JQ" "$p/.mcp.json" 2>/dev/null | sed "s|^|plugin $(basename "$(dirname "$p")")	|")"$'\n'
        [ -f "$p/.claude-plugin/plugin.json" ] &&
            MCP_NAMES="$MCP_NAMES$(jq -r '.mcpServers | if type == "object" then keys[] else empty end' \
                "$p/.claude-plugin/plugin.json" 2>/dev/null | sed "s|^|plugin $(basename "$(dirname "$p")")	|")"$'\n'
    done <<< "$(enabled_plugin_paths)"
}

probe_mcp() {
    local label name
    [ "$HAVE_JQ" = 1 ] || { printf 'cannot-check\tjq not found\n'; return; }
    while IFS="$TAB" read -r label name; do
        [ "$name" = "$1" ] && { printf 'ok\t%s\n' "$label"; return; }
    done <<< "$MCP_NAMES"
    printf 'missing\tnot configured for this project\n'
}

# ---------- simple probes ----------
probe_cli() {
    local p
    if p="$(command -v "$1" 2>/dev/null)" && [ -n "$p" ]; then printf 'ok\t%s\n' "$(tilde "$p")"
    else printf 'missing\tnot on PATH\n'; fi
}

probe_env() {
    case "$1" in [A-Za-z_]*) ;; *) printf 'cannot-check\tinvalid variable name\n'; return ;; esac
    printf '%s' "$1" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$' || { printf 'cannot-check\tinvalid variable name\n'; return; }
    # printenv sees exported variables only (not this script's own shell vars) and
    # its output is discarded, so the value is never printed.
    if [ -n "$(printenv "$1" 2>/dev/null | head -c 1)" ]; then printf 'ok\tset\n'; else printf 'missing\tunset\n'; fi
}

run_probe() { # probe -> "status<TAB>detail"
    local kind="${1%%:*}" name="${1#*:}"
    case "$1" in *:*) ;; *) printf 'cannot-check\tinvalid probe syntax (expected kind:name)\n'; return ;; esac
    if [ -z "$name" ] || ! printf '%s' "$name" | grep -qE "$NAME_RE"; then
        printf 'cannot-check\tinvalid probe name\n'; return
    fi
    case "$kind" in
        plugin) probe_plugin "$name" ;;
        skill)  probe_skill "$name" ;;
        mcp)    probe_mcp "$name" ;;
        cli)    probe_cli "$name" ;;
        env)    probe_env "$name" ;;
        remote) printf 'unknown-remote\tclaude.ai connector — check /mcp\n' ;;
        *)      printf 'cannot-check\tunknown probe kind\n' ;;
    esac
}

process_line() {
    local line="$1" tool probes probe result st detail worst="ok" total=0 oks=0
    case "$line" in
        *"|"*) ;;
        *) emit "$line" "" cannot-check "malformed line (expected tool|probe)"; emit "$line" "*" cannot-check "0/0 ok"; return ;;
    esac
    tool="${line%%|*}"; probes="${line#*|}"
    tool="$(printf '%s' "$tool" | awk '{$1=$1; print}')"
    probes="$(printf '%s' "$probes" | tr -d ' ')"
    for probe in $(printf '%s' "$probes" | tr '+' ' '); do
        result="$(run_probe "$probe")"
        st="${result%%"$TAB"*}"; detail="${result#*"$TAB"}"
        emit "$tool" "$probe" "$st" "$detail"
        total=$((total + 1))
        [ "$st" = ok ] && oks=$((oks + 1))
        [ "$(rank "$st")" -lt "$(rank "$worst")" ] && worst="$st"
    done
    [ "$total" -gt 0 ] || worst="cannot-check"
    emit "$tool" "*" "$worst" "$oks/$total ok"
}

main() {
    local line
    load_plugins
    load_mcp
    printf 'tool\tprobe\tstatus\tdetail\n'
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        case "$line" in ''|\#*) continue ;; esac
        [ -z "$(printf '%s' "$line" | tr -d ' \t')" ] && continue
        process_line "$line"
    done < "${TOOLS_FILE:-/dev/stdin}"
}

if [ "$TOOLS_FILE" = "-" ]; then TOOLS_FILE=""; fi
main
exit 0
