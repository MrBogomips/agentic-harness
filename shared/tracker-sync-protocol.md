# Tracker sync protocol

When a project runs **two** trackers — a repo-native tracker the agents work (Beads,
Backlog.md, git-bug, …) and a human-oriented SaaS tracker people watch (Jira, Linear, GitHub
Issues) — the two drift apart unless something keeps them in sync. This file defines that
sync: the lanes and their boundaries, the state store, identity and idempotency, concurrency,
conflict and failure policies, and the per-SaaS map. It is an instance-level companion to
`${CLAUDE_PLUGIN_ROOT}/shared/tracker-coordination.md`, under the generic protocol in
`${CLAUDE_PLUGIN_ROOT}/shared/coordination-protocol.md`.

`harness-setup` reads this file at **generation time** and inlines the relevant values into
the generated sync skill, agent, and sync config — the templates are in
`skills/harness-setup/references/tracker-sync-template.md`. The generated artifacts never
read this file at runtime.

## Source of truth and the three lanes

The repo-native tracker is the **source of truth** for every synced field; the SaaS tracker
is a projection humans watch. One direction of authority is what makes the sync tractable —
two writable masters need merge machinery (vector clocks, last-write-wins heuristics) that
silently loses someone's edit sooner or later. Three lanes, strictly bounded:

1. **Push (continuous, one-way).** Repo-tracker changes to synced fields propagate to the
   SaaS. Remote edits to title or labels are overwritten on the next push, with the
   overwritten value logged in `conflicts.md` — never discarded silently.
2. **Intake (one-time import).** Issues humans create in the SaaS — within the configured
   **intake filter** — are imported once into the repo-native tracker, marked
   `origin: remote`, and are from then on repo-owned like any other issue. Intake is not a
   second sync direction: after the import, the item follows the push and proposal rules.
3. **State proposals (the one controlled exception to source-of-truth-wins).** A remote
   change to an issue's *state* — a PM closes it in Jira as won't-do, blocks it, reopens it —
   is a deliberate human decision the sync must not fight. The sync (a) records it in
   `.tracker-sync/proposals.md` with both states and their sources, (b) **suspends state push
   for that item** until the proposal is resolved (title and label push continue), and
   (c) surfaces it in the run report. Adoption into the repo tracker happens only on
   user/orchestrator confirmation — at which point the proposal is marked resolved and state
   push resumes. This is a proposal lane, not field-level two-way merge.

**Full two-way merge is deliberately out** and recommended against: every field-level merge
policy either overwrites a human edit or overwrites an agent edit, and the failure is silent
by construction. If a future release revisits it, it revisits it against this protocol — the
lanes above are the supported model.

## Synced fields and the canonical state machine

| Field | Direction | Notes |
|---|---|---|
| title | push (remote edits overwritten + logged) | normalized for fingerprinting, below |
| description | **push-only** | excluded from the remote fingerprint entirely |
| state | push, with the proposal lane as the exception | via the canonical machine below |
| labels | push (namespaced; remote edits overwritten + logged) | sorted + case-folded for fingerprinting |
| commit / PR links | **push-only** | excluded from the remote fingerprint |
| priority, assignee | optional, **off by default** | enable explicitly at setup |

**Not synced (non-goals):** comments, attachments, worklogs, sprints/boards/epics, custom
fields, SaaS-side automation. The sync projects work state; it does not replicate a tracker.

**Canonical state machine:** `ready → in_progress → blocked → done → closed`. Each SaaS maps
to it through its state table (per-SaaS map, below). A remote state with **no canonical
mapping** is a no-op for that item plus a log entry — never guess a mapping at runtime.

## The sync state store — `.tracker-sync/`

Sync state lives at the **repo root**, not under `.claude/` — it is data, not harness
config; it is tracker-agnostic and survives a tracker migration.

```
.tracker-sync/
  map.jsonl        # one JSON record per issue pair — the authoritative ID map (git-tracked)
  cursor.json      # intake watermark ONLY (git-tracked)
  conflicts.md     # overwritten-value log, append-only (git-tracked)
  proposals.md     # open + resolved state proposals (git-tracked)
  reports/         # machine-local drift/run reports — GITIGNORED
```

Generation adds `.tracker-sync/reports/` to the project's `.gitignore`. **No secrets ever
live under `.tracker-sync/`** (see Credential posture).

**`map.jsonl` record** — one line per pair, updated in place:

```json
{"local_id": "bd-123", "remote_id": "PROJ-456", "remote_url": "https://…",
 "origin": "local|remote", "fp_local": "…", "fp_remote": "…",
 "last_synced_at": "2026-06-12T09:00:00Z", "state": "active|orphaned-remote|orphaned-local"}
```

- **Canonical ordering:** records sorted by `local_id`, one line per record, fixed key order
  as above. This keeps git merges line-stable when two branches touch different items.
- **`cursor.json` is the intake watermark only** — the last SaaS created/updated timestamp
  scanned, per remote. Push idempotency comes entirely from per-item fingerprints, so a lost
  or merge-conflicted cursor degrades to a **full intake re-scan** deduped against
  `map.jsonl` and the SaaS markers — an efficiency loss, never corruption. On an
  unresolvable merge conflict in `cursor.json`, delete it and re-scan.
- **`conflicts.md` / `proposals.md`** are append-mostly markdown. Each proposal carries a
  status line (`open` / `adopted` / `declined`) edited in place when it is resolved.

## Identity and idempotency

### Fingerprints

Per side, `fp = hash(canonical tuple of the two-way-sensitive fields)`: title, canonical
state (mapped through the per-SaaS state table), sorted namespaced labels. Normalization
before hashing: trim, collapse internal whitespace, case-fold labels, and map the remote
state to canonical *before* comparing. **Push-only fields — description, commit/PR links —
are excluded from the remote fingerprint entirely**: Jira returns descriptions as ADF rather
than the markdown that was pushed, and a naive whole-issue hash would flag a spurious change
on every run. "Changed since last sync" = current fp ≠ stored fp on that side.

### SaaS markers — the pre-create idempotency check

Each remote issue carries a namespaced marker — a label or remote link such as `repo:bd-123`
(per-SaaS convention below) — identifying its local counterpart. Before **creating** a
remote issue, the sync queries the SaaS by marker for that `local_id`; a hit means a
previous run created it but the map commit was lost — **re-link instead of re-create**. The
map stays primary; the marker is the recovery index *and* the duplicate-creation guard.

### Intake ordering

Import = create the local issue → append the map record → push the marker to the remote, in
that order. A re-run skips any `remote_id` already present in `map.jsonl` regardless of
marker state, so a failed marker write cannot cause a duplicate import. Imported issues are
marked `origin: remote` in the map and get a back-reference to the remote URL in the local
issue body.

## Concurrency policy

Sync **write** runs execute only from the **designated sync branch** — default: the
integration branch, normally `main` — recorded in the generated sync config. Write-run
preflight requires: on the sync branch, `.tracker-sync/` clean, branch up to date with its
remote. After a run, `.tracker-sync/` changes are committed (`chore(tracker-sync): …`) and
pushed with **one rebase-retry**; if the push still fails, stop and report — never force.
Read-only runs (the scheduled drift report) have no branch requirement.

There is no cross-machine lock. Designated-branch + clean-preflight + the marker pre-create
check together bound the race to "two simultaneous in-session write runs on the same
branch", which the preflight makes loud rather than silent.

## Conflicts, proposals, orphans

- **Conflict** (title / labels) = both fingerprints changed since `last_synced_at`. Policy:
  **source-of-truth-wins**, with both values appended to `conflicts.md` with their sources —
  never discarded. Alternatives (latest-timestamp-wins, a manual merge queue) are documented
  here only and not implemented: both reintroduce the silent-loss problem the one-way
  authority avoids.
- **State divergence is not a conflict** — it is a proposal (lane 3 above). Lifecycle:
  `open` (state push suspended for the item) → `adopted` (the repo tracker takes the remote
  state; push resumes) or `declined` (the repo state stands; the next push restores it
  remotely; push resumes).
- **Orphans:** `orphaned-remote` (a human deleted or archived the SaaS issue) and
  `orphaned-local` (the local issue vanished) are **terminal map states pending a user
  decision**. The sync never auto-recreates in either direction — a delete is a human
  decision, like a state change.

## Failure semantics

- A remote state with **no canonical mapping** → no-op for that item + log entry. Never
  guess.
- A **failed transition** (Jira screens can require fields the sync does not carry) →
  conflict-log entry + skip the item this run. No retry loop; the run report names the item
  and the reason.
- **Description push** converts repo markdown into whatever the role's tool accepts (the
  official MCPs accept markdown; `gh` is native markdown). Conversion fidelity is
  logged-not-blocking: a degraded description never fails the item.
- **Per-item failures:** retry once, then skip and report. The cursor and fingerprints
  advance only for items that completed, so re-runs are idempotent and pick up the skipped
  tail.

## Rate limits

Per-SaaS notes are in the map below. The skill rule is uniform regardless of SaaS: cap the
items processed per run (default 50, recorded in the sync config); on a 429 or
limit-exceeded response, **stop the phase**, record the position in the run report, and let
the next run resume from the map and cursor — never busy-retry against a limiter.

## Credential posture

SaaS access in every generated artifact goes through the **`human-tracker` role** in the
orchestrator's `tools.md` registry — never a hard tool name. Auth lives where the tool keeps
it (an MCP OAuth session, `gh auth`, an environment variable); **nothing under
`.tracker-sync/` or the sync config ever holds a token**. Scheduled headless runs are
read+report-only by design, which makes headless auth structural rather than operational:
when even read auth is absent, the preflight degrades to "report: human-tracker role
unavailable" and exits cleanly — a visible signal in `harness-review`'s stale-reports check,
not a silent failure.

## Per-SaaS map — Jira, Linear, GitHub Issues

The access path for each SaaS is its row in the per-tracker coordination map in
`${CLAUDE_PLUGIN_ROOT}/shared/tracker-coordination.md`; this map adds what the *sync*
needs. Values are a curated baseline — confirm against the tracker's own docs when a call
fails, and note that label character rules differ per SaaS (Jira labels cannot contain
spaces; adjust the marker spelling to what the instance accepts).

| | **GitHub Issues** | **Linear** | **Jira** |
|---|---|---|---|
| Access role | `human-tracker` → `gh` (authenticated) | `human-tracker` → official MCP (mcp.linear.app) | `human-tracker` → Atlassian MCP (mcp.atlassian.com) |
| Marker convention | label `repo:{local_id}` | label `repo:{local_id}` | label `repo-{local_id}` (no spaces; fall back to a remote link titled `repo:{local_id}` if labels are restricted) |
| Intake-filter shape | a label (repo identity already scopes the rest) | team and/or label | a JQL fragment — typically project + label |
| Rate-limit notes | secondary (content-creation) limits on rapid writes | complexity-based GraphQL budgets | Jira Cloud per-account API budgets |

### State-table starters

**GitHub Issues** — trivially two-state; the rest is carried by labels:

| Canonical | GitHub |
|---|---|
| ready | open |
| in_progress | open + label `in-progress` |
| blocked | open + label `blocked` |
| done | closed (reason: completed) |
| closed | closed (reason: not planned) |

**Linear** — the default workflow is near-1:1 with the canonical machine:

| Canonical | Linear |
|---|---|
| ready | Todo |
| in_progress | In Progress |
| blocked | Todo + label `blocked` (or the team's Blocked state, if one exists) |
| done | Done |
| closed | Canceled |

**Jira** — **elicited per project**: Jira workflows are per-instance, so a starter table
would mis-map most of them. At setup time, when the `human-tracker` role resolves, read the
project's live statuses and transitions via the Atlassian MCP and propose the
canonical→Jira mapping; otherwise interview the user. **Either way the user confirms the
table** before it is inlined into the generated sync config. A typical confirmed shape:

| Canonical | Jira (typical — confirm per project) |
|---|---|
| ready | To Do |
| in_progress | In Progress |
| blocked | Blocked (or In Progress + flag, where no Blocked status exists) |
| done | Done |
| closed | Done with resolution Won't Do (or the project's closing status) |
