#!/usr/bin/env bash
# Layer 1: behavioural test for skills/harness-doctor/scripts/check-system.sh
# Copies the fixture world (tests/fixtures/doctor) to a temp dir, adds the pieces
# git cannot hold reliably (broken symlink, absolute paths), runs the detector with
# a sandboxed HOME/PATH, and asserts statuses, secrecy, and read-only behaviour.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/skills/harness-doctor/scripts/check-system.sh"
FIXTURE="$REPO_ROOT/tests/fixtures/doctor"
SECRET_ENV_VALUE="ENV_SECRET_DO_NOT_PRINT"
ERRORS=0

red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
pass()  { green "PASS: $*"; }
fail()  { red "FAIL: $*"; ERRORS=$((ERRORS + 1)); }

command -v jq >/dev/null 2>&1 || { red "FAIL: jq is required"; exit 1; }
[ -x "$SCRIPT" ] || { red "FAIL: $SCRIPT missing or not executable"; exit 1; }

checksum_cmd() { if command -v shasum >/dev/null 2>&1; then shasum "$@"; else sha1sum "$@"; fi; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/doctor-test.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

# ---------- build the world ----------
cp -R "$FIXTURE/." "$TMP/world"
W="$TMP/world"
for f in "$W/bin/plugin-list.json" "$W/home/.claude/plugins/installed_plugins.json" "$W/home/.claude.json"; do
    sed -e "s|__HOME__|$W/home|g" -e "s|__PROJECT__|$W/project|g" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
ln -s "$W/home/.claude/skills/does-not-exist" "$W/home/.claude/skills/broken-skill"
mkdir -p "$TMP/jqbin"
ln -s "$(command -v jq)" "$TMP/jqbin/jq"

snapshot() { # listing + symlink targets + file checksums
    ( cd "$W" && find . | sort
      find . -type l | sort | while IFS= read -r l; do printf '%s -> %s\n' "$l" "$(readlink "$l")"; done
      find . -type f | sort | while IFS= read -r f; do checksum_cmd "$f"; done )
}
BEFORE="$(snapshot)"

run_doctor() { # $1 = PATH to use; extra args forwarded
    local path="$1"; shift
    ( cd "$W/project" &&
      env -u CLAUDE_CONFIG_DIR HOME="$W/home" PATH="$path" \
          DOCTOR_FIXTURE_TOKEN="$SECRET_ENV_VALUE" DOCTOR_SHIM_LOG="$SHIM_LOG" \
          bash "$SCRIPT" --project "$W/project" "$@" )
}

BASE_PATH="$TMP/jqbin:/usr/bin:/bin"
SHIM_LOG="$TMP/claude-shim.log"   # outside the snapshotted world
: > "$SHIM_LOG"
OUT="$(run_doctor "$W/bin:$BASE_PATH" "$W/tools.txt")" || fail "detector exited non-zero"
DEGRADED="$(run_doctor "$BASE_PATH" "$W/tools.txt")" || fail "degraded run exited non-zero"

# ---------- assertions ----------
expect() { # label output tool probe status [detail-substring]
    local label="$1" out="$2" tool="$3" probe="$4" status="$5" sub="${6:-}" row
    row="$(printf '%s\n' "$out" | awk -F'\t' -v t="$tool" -v p="$probe" '$1 == t && $2 == p { print; exit }')"
    if [ -z "$row" ]; then fail "$label: no row for $tool / $probe"; return; fi
    if [ "$(printf '%s' "$row" | cut -f3)" != "$status" ]; then
        fail "$label: $tool / $probe expected $status, got: $row"; return
    fi
    if [ -n "$sub" ] && ! printf '%s' "$row" | cut -f4 | grep -qF -- "$sub"; then
        fail "$label: $tool / $probe detail lacks '$sub': $row"; return
    fi
    pass "$label: $tool / $probe = $status${sub:+ ($sub)}"
}

[ "$(printf '%s\n' "$OUT" | head -1)" = "$(printf 'tool\tprobe\tstatus\tdetail')" ] \
    && pass "TSV header" || fail "TSV header wrong: $(printf '%s\n' "$OUT" | head -1)"

echo "=== plugins (claude CLI) ==="
expect cli "$OUT" ok-plugin     plugin:good-plugin@mkt     ok 1.0.0
expect cli "$OUT" byname        plugin:good-plugin         ok good-plugin@mkt
expect cli "$OUT" disabled      plugin:disabled-plugin@mkt disabled
expect cli "$OUT" elsewhere     plugin:proj-plugin@mkt     disabled-here
expect cli "$OUT" here          plugin:here-plugin@mkt     ok
expect cli "$OUT" stale         plugin:stale-plugin@mkt    stale
expect cli "$OUT" blocked       plugin:blocked-plugin@mkt  missing BLOCKLISTED
expect cli "$OUT" absent-plugin plugin:nope@mkt            missing
expect cli "$OUT" bare          plugin:bare-plugin@mkt     ok "unversioned"
if [ -s "$SHIM_LOG" ]; then fail "detector made unexpected claude calls: $(cat "$SHIM_LOG")"
else pass "claude called only with 'plugin list --json'"; fi
if printf '%s\n' "$OUT" | grep -q 'degraded'; then fail "cli run should not be degraded"; else pass "cli run not degraded"; fi

echo "=== skills ==="
expect cli "$OUT" okskill        skill:ok-skill        ok "~/.claude/skills/ok-skill"
expect cli "$OUT" brokenskill    skill:broken-skill    broken-link
expect cli "$OUT" syncedskill    skill:synced-skill    ok synced
expect cli "$OUT" agentskill     skill:agent-skill     ok "via skill-lock"
expect cli "$OUT" projskill      skill:proj-skill      ok project
expect cli "$OUT" providedskill  skill:provided-skill  ok plugin
expect cli "$OUT" hiddenskill    skill:hidden-skill    missing
expect cli "$OUT" elsewhereskill skill:elsewhere-skill missing
expect cli "$OUT" noskill        skill:no-such-skill   missing

echo "=== mcp ==="
expect cli "$OUT" usermcp     mcp:user-mcp          ok user
expect cli "$OUT" localmcp    mcp:local-mcp         ok local
expect cli "$OUT" projmcp     mcp:project-mcp       ok project
expect cli "$OUT" providedmcp mcp:provided-mcp      ok provider-plugin
expect cli "$OUT" manifestmcp mcp:manifest-mcp      ok provider-plugin
expect cli "$OUT" hiddenmcp   mcp:hidden-mcp        missing
expect cli "$OUT" othermcp    mcp:other-project-mcp missing

echo "=== cli / env / remote / syntax ==="
expect cli "$OUT" clitool   cli:sh                        ok
expect cli "$OUT" nocli     cli:definitely-not-a-tool-xyz missing
expect cli "$OUT" envset    env:DOCTOR_FIXTURE_TOKEN      ok set
expect cli "$OUT" envunset  env:DOCTOR_FIXTURE_UNSET      missing unset
expect cli "$OUT" shellvars env:CFG                       missing unset
expect cli "$OUT" shellvars env:TAB                       missing unset
expect cli "$OUT" shellvars env:PLUGIN_ROWS               missing unset
expect cli "$OUT" figma     remote:figma                  unknown-remote /mcp
expect cli "$OUT" weird     bogus:thing                   cannot-check "unknown probe kind"
expect cli "$OUT" badsyntax nocolon                       cannot-check "invalid probe syntax"
expect cli "$OUT" "malformed line without pipe" ""        cannot-check malformed

echo "=== rollups ==="
expect cli "$OUT" combo-missing  "*" missing      "1/3 ok"
expect cli "$OUT" combo-disabled "*" disabled     "1/2 ok"
expect cli "$OUT" combo-cannot   "*" cannot-check "1/2 ok"
expect cli "$OUT" combo-ok       "*" ok           "2/2 ok"
expect cli "$OUT" stale          "*" stale
expect cli "$OUT" figma          "*" unknown-remote

echo "=== degraded fallback (no claude CLI) ==="
expect degraded "$DEGRADED" ok-plugin     plugin:good-plugin@mkt     ok "(degraded)"
expect degraded "$DEGRADED" disabled      plugin:disabled-plugin@mkt disabled "(degraded)"
expect degraded "$DEGRADED" elsewhere     plugin:proj-plugin@mkt     disabled-here "(degraded)"
expect degraded "$DEGRADED" here          plugin:here-plugin@mkt     ok "(degraded)"
expect degraded "$DEGRADED" stale         plugin:stale-plugin@mkt    stale "(degraded)"
expect degraded "$DEGRADED" blocked       plugin:blocked-plugin@mkt  missing BLOCKLISTED
expect degraded "$DEGRADED" bare          plugin:bare-plugin@mkt     ok "(degraded)"
expect degraded "$DEGRADED" providedskill skill:provided-skill       ok plugin
expect degraded "$DEGRADED" providedmcp   mcp:provided-mcp           ok

echo "=== usage errors ==="
set +e
run_doctor "$BASE_PATH" --bogus >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && pass "unknown option exits 2" || fail "unknown option exited $rc (want 2)"
run_doctor "$BASE_PATH" "$W/no-such-file" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && pass "unreadable tools file exits 2" || fail "unreadable tools file exited $rc (want 2)"
STDIN_OUT="$(printf 'x|cli:sh\n' | run_doctor "$BASE_PATH")"; rc=$?
set -e
[ "$rc" -eq 0 ] && printf '%s\n' "$STDIN_OUT" | grep -q "$(printf 'x\tcli:sh\tok')" \
    && pass "reads tools from stdin" || fail "stdin mode failed (rc=$rc)"

echo "=== secrecy ==="
ALL="$OUT$DEGRADED$STDIN_OUT"
for s in SECRET_VALUE_DO_NOT_PRINT SECRET_ARG_DO_NOT_PRINT "$SECRET_ENV_VALUE" "Bearer"; do
    if printf '%s' "$ALL" | grep -qF -- "$s"; then fail "secret '$s' leaked into output"; else pass "secret '$s' not printed"; fi
done

echo "=== read-only ==="
AFTER="$(snapshot)"
[ "$BEFORE" = "$AFTER" ] && pass "fixture tree unchanged" || fail "fixture tree modified by detector"

echo ""
if [ "$ERRORS" -gt 0 ]; then red "FAILED: $ERRORS assertion(s)"; exit 1; fi
green "PASSED: harness-doctor detector"
