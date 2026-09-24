---
name: harness-doctor
description: "Check whether this machine has what a project's agentic harness needs — the plugins, skills, MCP servers, CLIs, and API-key variables named in its tools registry — and report each as ok, missing, disabled, stale, or broken-link, read-only. Use to check the system configuration for a harness, to diagnose why a harness tool is unavailable, to see what is missing before or after a harness build, or when a generated {domain}-setup-check skill hands off to it. It proposes pinned install rows for what is missing and hands them to harness-setup to install under approval; it installs nothing itself. Not for assessing how well a harness is used (that is harness-review), not for choosing tools (tool discovery in harness-setup, or visual-advisor), and not for debugging Claude Code itself."
model: inherit
disallowed-tools: Write, Edit, NotebookEdit
---

# Harness doctor — check the system a harness depends on (read-only)

A harness names its tools by role in `tools.md`; a teammate's machine, a fresh laptop, or a CI
runner may not have them. This skill checks, deterministically, whether each tool the harness
relies on is actually present and usable here, and turns every gap into a **proposed install
row** with a pinned source. It never installs, enables, or edits anything: installing is a write,
and writes belong to `harness-setup`, gated by its Step 2b change manifest.

It lives in the plugin so every harness benefits when it improves; each generated harness carries
a thin `{domain}-setup-check` skill that calls this one when the plugin is present and falls back
to its own inline checks when it is not.

## The read-only contract

Run nothing that mutates the machine or the project: no `claude plugin install`, no
`npx skills add`, no `claude mcp add`, no edits to settings. The skill sets `disallowed-tools:
Write, Edit, NotebookEdit`; `Bash` stays available for the detection script and read-only
queries — the prose governs it. **Never print a secret**: API keys are checked for presence only,
and config files are read for server *names*, never for their `env` or `args` values.

## Step 1: Gather the required tools

- **From a harness** — read the `tools.md` registry in the `references/` directory of the harness orchestrator skill. Take
  each row's preferred tool and its alternative. Use the `Kind` and `Source` columns when
  present; an older registry without them is fine — infer the kind from the tool name and mark
  the row "Kind inferred" in the report.
- **From a caller** — `visual-advisor` or `harness-setup` may pass a tool list directly.
- **Standalone with neither** — say there is no registry to check against, and offer
  `harness-setup` tool discovery instead of guessing.

## Step 2: Build the probe list and run the script

Translate each tool into one line `tool|probe[+probe…]`. A tool can need more than one thing
(lavish is a skill *and* needs `npx`):

| Probe | Checks |
|---|---|
| `plugin:<name@marketplace>` | installed, enabled for this project, install path still on disk |
| `skill:<name>` | a `SKILL.md` in the user, project, synced, or `~/.agents` skill dirs, or inside an enabled plugin |
| `mcp:<name>` | a server of that name in user, project, `.mcp.json`, or enabled-plugin config |
| `cli:<cmd>` | the command is on `PATH` |
| `env:<VAR>` | the variable is set (value never shown) |
| `remote:<name>` | a claude.ai connector, or a skill built into the host (e.g. `dataviz`) — cannot be checked from files |

Then run `bash ${CLAUDE_PLUGIN_ROOT}/skills/harness-doctor/scripts/check-system.sh --project "$PWD"`
with the lines on stdin. It prefers
`claude plugin list --json` for plugins (the CLI resolves scope and enablement correctly) and
falls back to the plugin files — marking the detail `(degraded)` — when the CLI is absent, fails,
or returns an unexpected shape.
It respects `CLAUDE_CONFIG_DIR`. Supported on macOS, Linux, and WSL; elsewhere it exits with a
message, and the skill reports that the check could not run.

## Step 3: Report

Present one table, worst first:

| Tool | Role | Status | Detail | Next step |
|---|---|---|---|---|

The statuses and what each means:

- **ok** — present and usable.
- **missing** — not found anywhere; propose an install row.
- **disabled** — installed but turned off; propose an enable row.
- **disabled-here** — a project-scoped plugin enabled for a different project path.
- **stale** — registered, but its install path is gone (a moved or deleted cache); propose a
  reinstall row.
- **broken-link** — a skill symlink whose target no longer exists.
- **unknown-remote** — a claude.ai connector; ask the user to confirm with `/mcp`. Never report
  it as missing.
- **cannot-check** — `jq` is absent (plugin and MCP probes need it) or a probe is malformed; say
  which. A missing `claude` CLI does not cause this — the plugin probes degrade to the files and
  say `(degraded)`.

When a role's preferred tool is not ok but its alternative is, say the harness still works on
the alternative — a gap is not always a blocker.

## Step 4: Propose install rows — never run them

For each fixable gap, draft a Step 2b manifest row, `install {role} -> {tool}`, under the
**install safety contract**, which `harness-setup` follows when it carries the row out:

1. **One command per approval** — never a batch.
2. **Show provenance before asking** — the official repo URL, license, last release or push, and
   the exact resolved command.
3. **Pin** — `pkg@<version>`, `owner/repo@<tag|sha>`, or a marketplace plugin at a known
   version. Never an unpinned `npx -y pkg`. Record the pin in `tools.md` `Source`.
4. **Refuse blocklisted plugins** — a row the script marks `BLOCKLISTED` is reported, not
   proposed.
5. **Show MCP servers in full** — the complete `command` and `args` to be registered, since that
   is what will run on the user's machine.
6. **Project scope by default** — user scope only when the user asks for it.
7. **Credentials stay with the user** — name the variable or login step the tool needs; never ask
   for or handle the secret.

Then hand off: invoked from `harness-setup`, return the rows for its manifest; standalone, present
them as a **tools-only manifest** and tell the user that applying it is `harness-setup`'s job.

## Error handling

- **Script fails or cannot run** — report the error verbatim and fall back to the checks a
  person can confirm by hand (`command -v`, `claude plugin list`, `/mcp`); do not guess statuses.
- **Registry row unparseable** — report the row as `cannot-check` with the reason; continue with
  the rest.
- **Health of MCP servers** — this skill checks presence, not liveness. If the user wants a live
  check, suggest `claude mcp list`, noting that it starts every stdio server and can be slow.

## References

- `scripts/check-system.sh` — the deterministic, read-only detector (TSV out: `tool`, `probe`,
  `status`, `detail`, plus a per-tool rollup row with probe `*`).
- `${CLAUDE_PLUGIN_ROOT}/shared/harness-model.md` — why tools are referenced by role.
