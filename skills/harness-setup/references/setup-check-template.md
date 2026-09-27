# Setup-check skill generation template

What `harness-setup` generates whenever the orchestrator's `tools.md` has at least one row: the
project's `{domain}-setup-check` skill. It lets anyone who clones the project — a teammate, a
fresh laptop, a CI runner — find out whether their machine has what the harness needs.

## Design

- **Two tiers.** When the agentic-harness plugin is installed at 0.10.0 or later, the skill hands
  off to its `harness-doctor` skill, which has the full deterministic detector — so every harness
  benefits when the plugin improves. When the plugin is absent or older, the skill runs its own
  inline checks. It is never a dead pointer.
- **Reads the registry at runtime.** The list of tools lives in `tools.md`, not in this skill, so
  a registry change needs no edit here.
- **Read-only.** It reports and proposes; installing goes through harness setup's approved
  change manifest, one pinned command at a time.
- **Self-contained.** No `${CLAUDE_PLUGIN_ROOT}` path; the Step 5 checker (`scripts/check-generated.sh`) applies.

## Generated skill — `.claude/skills/{DOMAIN}-setup-check/SKILL.md`

````markdown
---
name: {DOMAIN}-setup-check
description: "Check whether this machine has the tools the {DOMAIN_LABEL} harness needs — the plugins, skills, MCP servers, CLIs, and API-key variables in its tools registry — and explain how to add what is missing. Use on 'check my setup', 'is my environment ready', 'onboard this machine', 'why is tool X unavailable', after cloning the project, or when a harness skill reports a missing tool. Read-only: it installs nothing without approval."
model: inherit
effort: low
---

# {DOMAIN_LABEL} setup check

The harness names its tools by role in
`.claude/skills/{DOMAIN}-orchestrator/references/tools.md`. This skill checks each one on the
current machine. It changes nothing.

## Step 1 — Prefer the full check

If the `agentic-harness:harness-doctor` skill is available in this session **and** the installed
agentic-harness plugin is version 0.10.0 or later, invoke it with the registry path above and
stop here — it reports every status, including stale and disabled installs, and proposes pinned
install rows. If it is not available, or older, continue with the inline check.

## Step 2 — Inline check

Read `tools.md`. For each row, check the **preferred** tool and then its **alternative**, using
the `Kind` column (infer it from the tool name when the column is missing):

| Kind | How to check (read-only) |
|---|---|
| `cli` | `command -v <cmd>` succeeds |
| `skill` | a `<name>/SKILL.md` exists under `.claude/skills/`, `~/.claude/skills/`, or `~/.agents/skills/` (a symlink must resolve) |
| `plugin` | the plugin appears as installed and enabled in `claude plugin list` |
| `mcp` | the server name appears in `claude mcp list`, `.mcp.json`, or `/mcp` — `claude mcp list` starts every server and can be slow; warn first |
| `env` | the variable is set — test for presence only, **never print its value** |
| `remote` | a claude.ai connector — ask the user to confirm it in `/mcp` |

A `+`-joined kind needs every part.

## Step 3 — Report

| Role | Tool | Status | Next step |
|---|---|---|---|

Status is **ok**, **missing**, **disabled**, **broken** (a symlink or install path that points
nowhere), or **unconfirmed** (remote, or a check that could not run). When the full check ran,
its statuses map onto these: stale and broken-link → broken; disabled-here → disabled;
unknown-remote and cannot-check → unconfirmed. When the preferred tool is
missing but the alternative is ok, say the harness still works on the alternative.

## Step 4 — Help with what is missing

For each gap, show the row's `Source` (the pinned install command) and what it will change. Do
not run it: installing is a harness change. Offer to apply the missing installs through harness
setup, which asks for approval one command at a time and shows each tool's provenance first.
Credentials stay with the user — name the variable or login step, never ask for the secret.

For the most thorough check, the agentic-harness plugin provides `harness-doctor`:
`claude plugin marketplace add {PLUGIN_MARKETPLACE_REPO}` then
`claude plugin install agentic-harness@{PLUGIN_MARKETPLACE_NAME}`. This is optional — the check
above is complete on its own.
````

## Filling the placeholders

| Placeholder | Value |
|---|---|
| `{DOMAIN}`, `{DOMAIN_LABEL}` | the harness domain slug and its readable name |
| `{PLUGIN_MARKETPLACE_REPO}` | `MrBogomips/agentic-harness` |
| `{PLUGIN_MARKETPLACE_NAME}` | `mrbogomips-harness` |
