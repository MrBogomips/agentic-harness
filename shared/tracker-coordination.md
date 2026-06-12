# Tracker coordination

The issue-tracking instance of the harness coordination protocol. The protocol itself — the
two-way handoff, auto-invokable vs human-gated activation, and the two rules (**one owner per
phase/concern**, **one source of truth per artifact**) — is in
`${CLAUDE_PLUGIN_ROOT}/shared/coordination-protocol.md`; read it first. This file applies it to
issue trackers: a tracker owns the **work-state concern** — what work exists, what is ready,
and what state each item is in — and the per-tracker map below gives the concrete values
`harness-setup` inlines into the generated orchestrator. Detection of which tracker is present
is a separate concern: see `${CLAUDE_PLUGIN_ROOT}/shared/detection-signatures.md`.

## The tracker coordination model

Unlike an SDD system, a tracker does not own a phase of the workflow — it owns a concern that
**brackets** the workflow. The orchestrator touches it at two points:

1. **Phase 0 (intake & triage) — pull or create.** Once triage routes a request in as in-domain
   work: if a matching ready item exists (`{READY_QUERY}`), claim it and carry its ID through
   the run; if the work is new, create the issue (`{CREATE_CMD}`) so the tracker owns the work
   state from the start. For a human-gated tracker (a SaaS UI with no configured CLI/MCP
   access), emit the contextual prompt and **pause** per the protocol.
2. **Integrate / finish — write status back.** When the deliverable is written, update the
   issue (`{STATUS_WRITEBACK}`) — close it or transition its state, referencing the
   deliverable's path. Never delete issues and never rewrite human-authored issue prose — the
   tracker owns intent and history, the harness owns execution.

Between those two points the issue is **referenced, not copied**: agents carry the issue ID in
workspace artifact headers and read the issue in place. The orchestrator keeps no parallel
status file — work state has exactly one owner.

## Per-tracker coordination map

`harness-setup` looks up the detected tracker's row and inlines these concrete values into the
orchestrator. Commands are the curated baseline; confirm against the tracker's own docs if a
flag fails.

| Tracker | Ready-work query | Create | Status write-back | Auto-invokable? |
|---|---|---|---|---|
| **Beads (`bd`)** | `bd ready --json` | `bd create "title"` | claim with `bd update {id} --claim`; close with `bd close {id} "summary"` | yes (CLI) |
| **Backlog.md** | `backlog task list` (CLI or its MCP server) | `backlog task create` | `backlog task edit` status transition | yes (CLI / MCP) |
| **git-issues** | `issues next` | author a new `.issues/` entry per its conventions | `issues claim {id}` → `issues done {id}` | yes (CLI) |
| **Beans** | `beans list` or a GraphQL query | `beans create` | `beans update` / `beans archive` | yes (CLI) |
| **git-bug** | `git bug ls` | `git bug add` | update state / comment via the `git bug` CLI | yes (CLI) |
| **GitHub Issues** | `gh issue list --json number,title,state,labels` | `gh issue create` | `gh issue close` / `gh issue comment` | yes (`gh`, authenticated) |
| **Linear** | its official MCP server (mcp.linear.app) | MCP create-issue tool | MCP update/comment tools | yes when the MCP server is configured; otherwise human-gated |
| **Jira** | the Atlassian MCP server (mcp.atlassian.com) | MCP create tool | MCP transition/comment tools | yes when the MCP server is configured; otherwise human-gated |

For Linear and Jira without a configured MCP server, every touch is human-gated: emit the
contextual prompt (what to file or update, with the values to enter), pause, and resume on the
user's confirmation. Do not scrape or guess at SaaS state.

### Taskmaster boundary — one owner for work state

Taskmaster (`.taskmaster/`) tracks **spec-derived task state**, not general issue intake; it
belongs to the spec process (see `${CLAUDE_PLUGIN_ROOT}/shared/sdd-coordination.md`). When
Taskmaster co-exists with a general tracker, keep one owner per item: work decomposed from a
spec routes its status through `.taskmaster/tasks/tasks.json`; bugs and general work intake
route through the tracker. Never mirror the same item's state in both.

## How `harness-setup` uses this

1. After detecting the present tracker (Step 0), look up its row above and capture the
   **coordination context**: `{tracker, version, entry point, ready-work query, create
   convention, status write-back, auto-invokable}`.
2. With the user, settle which phases touch the tracker (phase 0 pull/create, integrate
   write-back) and whether access is auto-invokable or human-gated (Step 2). Fold the decision
   into the change manifest.
3. Splice the **Tracker coordination addenda** from `harness-setup`'s
   `references/orchestrator-template.md` into the chosen template (A / B / C), substituting the
   concrete values from the coordination context (Step 5). The generated orchestrator must be
   self-contained — inline the commands; do not leave it pointing at this file.
4. Record the relationship in the `CLAUDE.md` pointer's **Issue tracking** line — see
   `${CLAUDE_PLUGIN_ROOT}/shared/claude-md-pointer.md`.
