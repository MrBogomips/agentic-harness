# Tracker-sync generation templates

What `harness-setup` generates when the process-layers gate's **sync sub-step** runs: the
project's `tracker-sync` skill, its sync config, the sync agent, the orchestrator splice,
and (when accepted) the schedule registration. The model behind every value here — lanes,
state store, fingerprints, markers, concurrency, failure rules, and the per-SaaS map — is
`${CLAUDE_PLUGIN_ROOT}/shared/tracker-sync-protocol.md`; read it before generating.

The sub-step is offered **only when both tracker kinds are present or declared**: a
repo-native (agentic) tracker *and* a human-oriented SaaS tracker (Jira, Linear, GitHub
Issues). Its preflight, the manifest rows, and the placeholder verification are defined in
the SKILL.md (Step 0.5, Step 2b, Step 5).

## Generation rules

1. **Inline everything.** The generated files carry concrete values — tracker commands, the
   confirmed state table, the marker spelling, the intake filter. They never reference
   `${CLAUDE_PLUGIN_ROOT}` paths and never read plugin files at runtime. The one runtime
   lookup the generated skill makes is its **own** `references/mapping.md` (the sync
   config) and the orchestrator's `tools.md` role registry.
2. **SaaS access by role.** Every generated artifact reaches the SaaS through the
   `human-tracker` role in the orchestrator's `tools.md` — never a hard tool name. If that
   role is not yet registered, register it in the same manifest (the per-SaaS access path
   is in the protocol doc's map).
3. **Placeholder check.** After writing, run the Step 5 placeholder verification over every
   generated file — any unsubstituted `{PLACEHOLDER}` or `${CLAUDE_PLUGIN_ROOT}` reference
   fails the run.
4. **Gitignore.** Add `.tracker-sync/reports/` to the project's `.gitignore` (one manifest
   row).

## Eliciting the sync config

These values are per-project and are settled **with the user** before the Step 2b manifest;
the confirmed answers are inlined into `mapping.md`:

- **State table.** GitHub Issues and Linear start from the protocol doc's starter tables —
  present and confirm. **Jira is elicited**: when the `human-tracker` role resolves, read
  the project's live statuses and transitions via the Atlassian MCP and propose the
  canonical→Jira mapping; when it does not, interview the user for the project's workflow.
  Either way the user confirms the table before it is written.
- **Intake filter** — the SaaS-side boundary of "this repo's issues". Jira: a JQL fragment
  (typically project + label); Linear: team and/or label; GitHub: a label. Unmapped issues
  outside the filter are invisible to the sync; the drift report counts them so a
  mis-scoped filter is noticeable.
- **First-run backfill** — what to do with pre-existing items. `push-all-open` (every open
  repo issue gets a remote projection), `new-from-now` (only issues created or changed
  after setup; the cursor is initialized to setup time), or `selected` (the user picks).
  **Default offer: `new-from-now`** — bulk-creating dozens of SaaS issues unannounced is
  noise. The choice defines cursor initialization.
- **Designated sync branch** — default: the integration branch, normally `main`.
- **Cadence** for the scheduled drift report — default **daily on workdays**, changeable at
  the manifest step.
- **Per-run item cap** — default 50.
- **Optional fields** — priority and assignee sync are **off by default**; enable only on
  an explicit yes.

## Generated skill — `.claude/skills/tracker-sync/SKILL.md`

````markdown
---
name: tracker-sync
description: "Keep {LOCAL_TRACKER} (the source of truth) and {SAAS} in sync. Use on 'sync the trackers', 'push issues to {SAAS}', 'import {SAAS} issues', 'tracker drift report', or when the orchestrator's integrate phase invokes it for the items just completed. Three modes: scoped (only the items touched this run), full (push + intake + reconcile), report (read-only drift report, safe headless). Not for creating or working issues — that is the orchestrator's job."
model: inherit
---

# Tracker sync — {LOCAL_TRACKER} ⇄ {SAAS}

{LOCAL_TRACKER} is the **source of truth** for every synced field; {SAAS} is a projection
humans watch. Remote title/label edits are overwritten on the next push and logged — never
silently. Remote *state* changes are **proposals**, never fought: log, suspend state push
for that item, surface for adoption. All configuration — field map, state table, marker,
intake filter, branch, cadence, cap — is in `references/mapping.md`; read it first.

Sync state lives in `.tracker-sync/` at the repo root: `map.jsonl` (the ID map, canonical
order: sorted by `local_id`, fixed key order), `cursor.json` (intake watermark only),
`conflicts.md`, `proposals.md`, and gitignored `reports/`.

## Run modes

| Mode | Trigger | Writes |
|---|---|---|
| `scoped` | the orchestrator's integrate write-through | pushes only the item(s) touched this run |
| `full` | on-demand / catch-up ("sync the trackers") | full push + intake + reconcile |
| `report` | the scheduled headless run, or on demand | **nothing** — drift report to `.tracker-sync/reports/` |

`scoped` skips intake and reconcile. `report` executes every phase **read-only** and is the
only mode a headless run may use — headless runs write nothing, anywhere.

## Phases

1. **Preflight.** Resolve the `agentic-tracker` and `human-tracker` roles via the
   orchestrator's `tools.md`; verify both answer with a cheap real call ({READY_QUERY} on
   the local side, a {SAAS} ping via the role on the remote side). Role unavailable → in
   `report` mode, report exactly that and exit cleanly; in write modes, stop and tell the
   user. Write modes additionally require: on branch `{SYNC_BRANCH}`, `.tracker-sync/`
   clean, branch up to date with its remote.
2. **Load state** — `map.jsonl`, `cursor.json`, open proposals. A missing or conflicted
   cursor is not an error: delete it and fall back to a full intake re-scan deduped against
   the map and the markers.
3. **Push.** Diff local fingerprints (title + canonical state + sorted namespaced labels,
   normalized) against the map. Before creating a remote issue, query {SAAS} by marker
   (`{MARKER_CONVENTION}`) for that `local_id` — a hit means re-link, not re-create. Update
   changed items; **skip the state field for any item with an open proposal**. Description
   and commit/PR links are push-only and excluded from remote fingerprints.
4. **Intake.** Scan {SAAS} within the intake filter (`{INTAKE_FILTER}`) from the cursor.
   For each unmapped issue: create the local issue → append the map record
   (`origin: remote`) → push the marker to the remote, in that order; skip any `remote_id`
   already in the map. Advance the cursor per-item.
5. **Reconcile.** Remote title/label drift → overwrite on push + append both values to
   `conflicts.md` with sources. Remote **state** drift → record a proposal in
   `proposals.md` (`open`), suspend state push for that item, surface it in the report.
   Remote issue deleted/archived → mark the pair `orphaned-remote`; local issue vanished →
   `orphaned-local`. Orphans are terminal pending a user decision — **never auto-recreate**
   in either direction.
6. **Report & commit.** Report created / updated / imported / skipped / conflicts /
   proposals / orphans / rate-limit position. Write modes: commit `.tracker-sync/` changes
   (`chore(tracker-sync): …`) and push with one rebase-retry; if the push still fails, stop
   and report — never force. Report mode: write `.tracker-sync/reports/{date}-drift.md`
   only.

## Failure rules

- A remote state with no canonical mapping → no-op for that item + log entry. Never guess.
- A failed {SAAS} transition → conflict-log entry + skip this run; the report names the
  item and reason. No retry loops.
- Degraded description conversion is logged, never blocking.
- Per-item failure: retry once, then skip and report. Fingerprints and cursor advance only
  for completed items, so re-runs pick up the skipped tail.
- Rate limits: process at most {ITEM_CAP} items per run; on a 429/limit response stop the
  phase, record the position in the report, and let the next run resume. Never busy-retry.
- Proposal resolution (on user/orchestrator confirmation): `adopted` → apply the remote
  state to {LOCAL_TRACKER}, mark resolved, resume state push; `declined` → mark resolved,
  resume state push (the next push restores the repo state remotely).
````

## Generated sync config — `.claude/skills/tracker-sync/references/mapping.md`

````markdown
# Tracker-sync config — {LOCAL_TRACKER} ⇄ {SAAS}

Confirmed with the user on {DATE}. Edit only through `harness-setup`.

## Access

| Side | Role (in the orchestrator's tools.md) | Entry point |
|---|---|---|
| local | `agentic-tracker` | {LOCAL_TRACKER} — ready query `{READY_QUERY}` |
| remote | `human-tracker` | {SAAS_ACCESS_PATH} |

## Field map

title (push; remote edits overwritten + logged) · description (push-only) · state (push via
the table below; remote changes → proposals) · namespaced labels (push) · commit/PR links
(push-only) · priority: {on|off} · assignee: {on|off}

## State table (confirmed)

| Canonical | {SAAS} |
|---|---|
| ready | {…} |
| in_progress | {…} |
| blocked | {…} |
| done | {…} |
| closed | {…} |

## Sync parameters

| Parameter | Value |
|---|---|
| Marker convention | {MARKER_CONVENTION} |
| Intake filter | {INTAKE_FILTER} |
| Backfill choice | {push-all-open | new-from-now | selected} (cursor initialized accordingly) |
| Designated sync branch | {SYNC_BRANCH} |
| Scheduled cadence | {CADENCE} (default: daily on workdays) |
| Headless posture | **report-only** — fixed; headless runs write nothing |
| Per-run item cap | {ITEM_CAP} |
````

## Generated agent — `.claude/agents/tracker-sync-agent.md`

One agent: push and pull are sequential phases over shared state, so splitting buys
nothing. Spawn it with the `general-purpose` type.

````markdown
---
name: tracker-sync-agent
description: Executes tracker-sync runs ({LOCAL_TRACKER} ⇄ {SAAS}) — scoped, full, or read-only report mode — for the tracker-sync skill.
model: inherit
---

# Tracker-sync agent

**Core role.** Execute one tracker-sync run in the requested mode, following
`.claude/skills/tracker-sync/SKILL.md` and its `references/mapping.md` exactly.

**Working principles.**
- Runs are idempotent: fingerprints and markers decide every write; re-running is always
  safe.
- Never delete on either side; orphans are marked and reported, never reconciled silently.
- Never overwrite a human state decision — state divergence becomes a proposal, and state
  push stays suspended for that item while the proposal is open.
- Record every conflict with both values and their sources; discard nothing.
- Reach {SAAS} only through the `human-tracker` role in the orchestrator's `tools.md`;
  reach {LOCAL_TRACKER} through the `agentic-tracker` role. No hard-coded tool names, no
  credentials anywhere in the repo.
- In `report` mode, write nothing except `.tracker-sync/reports/` — including when a role
  fails to resolve: that outcome *is* the report.

**Input.** The mode (`scoped` / `full` / `report`) and, for scoped, the local issue ID(s)
touched this run. **Output.** The run report (created / updated / imported / skipped /
conflicts / proposals / orphans / rate-limit position), and in write modes the committed
`.tracker-sync/` state.

**Error handling.** Per-item retry once, then skip and report; stop a phase on a rate
limit; stop entirely (and say why) when a write-mode preflight fails.
````

## Trigger wiring

1. **Always — orchestrator write-through.** Splice **Addendum T4** from the Tracker
   coordination section of `references/orchestrator-template.md` into the generated
   orchestrator, immediately after Addendum T3. It invokes `tracker-sync` in `scoped` mode
   for the item(s) just written back — cheap, and keeps the projection fresh on every
   completed run.
2. **Offered (manifest-gated) — scheduled drift report.** A read-only `report`-mode run on
   the user's machine, default daily on workdays. One manifest row per schedule
   (`register schedule`), marked **environment-level** — approving it changes the user's
   machine, not the repo. Registration per venue:
   - **Claude Code local scheduled agent**, where the installation supports it: register a
     scheduled agent that runs `/tracker-sync report` against the repo at the confirmed
     cadence.
   - **Crontab**, otherwise: add a line such as
     `0 9 * * 1-5 cd {REPO_PATH} && claude -p "/tracker-sync report"`
     (09:00 on workdays — adjust to the confirmed cadence).
   - **Unregister** is the symmetric removal (delete the scheduled agent / remove the
     crontab line), also a manifest row.
3. **Documented fallback — manual.** Any mode runs on demand: in-session ("sync the
   trackers", "tracker drift report") or `claude -p "/tracker-sync {mode}"`.

**Hooks are rejected** as a trigger: a sync run is agentic, multi-step, and network-bound —
not the deterministic, fast command a hook needs to be.
