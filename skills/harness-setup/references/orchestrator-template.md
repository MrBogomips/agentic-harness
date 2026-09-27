# Orchestrator template

The orchestrator is the top-level skill that coordinates the team. There is one template. Fill
it with the team's **contract**: who takes part, what each produces and where, what each phase
reads and writes, and when a phase is done. Then inline the mechanics block for the execution
mode chosen in Step 2. Leave the steps *inside* a phase to the model. Current models plan that
work well from a clear contract, and a hand-written step script over-constrains them. Keep
exact steps only where one sequence is the safe one (workspace archiving, team teardown,
tracker write-back).

## Table of contents

- [Orchestrator template](#orchestrator-template)
  - [Table of contents](#table-of-contents)
  - [The template](#the-template)
  - [Mode mechanics — inline one](#mode-mechanics--inline-one)
  - [SDD coordination](#sdd-coordination)
  - [Tracker coordination](#tracker-coordination)
  - [Authoring rules](#authoring-rules)
  - [Follow-up keywords](#follow-up-keywords)

---

## The template

> If the project has an installed SDD system and/or issue tracker, also splice in the matching
> [SDD coordination](#sdd-coordination) addenda (phase 0, prepare, integrate) and/or
> [Tracker coordination](#tracker-coordination) addenda (phase 0, work, integrate), so the
> orchestrator hands work to the spec process and keeps the tracker as the work-state owner.

````markdown
---
name: {domain}-orchestrator
description: "Entry point for all {domain} work in this repo — invoke before responding to any {domain} request. Coordinates the {domain} agents to produce {deliverable}. {initial keywords}. Also use for follow-ups: re-run, update, modify, supplement, improve the previous result, and everyday {domain} requests."
model: inherit
---

# {Domain} orchestrator

Coordinates the {domain} agents to produce {final deliverable} for {audience}. {One line on
the quality bar: what makes the deliverable good enough to hand over.}

## Execution mode: {subagent | agent team | hybrid}

{MODE_MECHANICS: the block for the chosen mode, inlined from the harness-setup reference}

## Team

| Member | Agent file | Skills | Output |
|--------|------------|--------|--------|
| {member-1} | `.claude/agents/{member-1}.md` | {skill} | `_agents_workspace/{phase}_{member-1}_{artifact}.md` |

## Phase 0: intake & triage (always first; this skill is the repo entry point)

This skill runs for every prompt, so triage first:
- Trivial, conversational, or outside {domain}: answer directly (or take the obviously small
  correct action) and stop. Spawn no agents and open no workspace.
- In-{domain} work: run the context check, then continue.

Context check:
- `_agents_workspace/` absent → initial run.
- Present, and the request changes part of a previous result → partial re-run: re-invoke only
  the affected member, pass it the path of its prior output, and overwrite only that output.
- Present, and the request brings new input → move the old workspace to
  `_agents_workspace/archive/{YYYYMMDD_HHMMSS}/`, then run as initial.

## Phases

| Phase | Owner | Reads | Writes | Done when |
|-------|-------|-------|--------|-----------|
| 1 prepare | orchestrator | the request | `_agents_workspace/00_input/` | input saved; scope and {what to identify} stated |
| 2 {main work} | {members} | `00_input/` | the member outputs in the Team table | {checkable condition} |
| 3 integrate | orchestrator | every member output | {user's target path} | deliverable written; conflicts recorded with both sources |

Plan the work inside each phase from this contract. Run members whose inputs are ready in
parallel.

## Finish

Keep `_agents_workspace/`; never delete intermediate work. Report to the user what was produced,
where it is, and anything omitted, with the reason.

## Failure policy

- A member fails: retry once, then continue without its result and note the omission.
- Most members fail: tell the user and confirm whether to continue.
- Members disagree: record both positions with their sources; delete neither.

## Test scenarios

- **Normal:** {input} → prepare → {members} produce their outputs → integrate → the
  deliverable exists at {path}.
- **Error:** {member} fails twice → the run integrates the rest → the report names the gap.
````

## Mode mechanics — inline one

Replace `{MODE_MECHANICS}` with the block for the mode chosen in Step 2. The generated
orchestrator cannot read `${CLAUDE_PLUGIN_ROOT}/shared/execution-modes.md` at runtime. That
file holds the full decision logic and the fallback mapping.

**Subagent** (the default):

```text
Spawn each member with the Agent tool, `subagent_type` = its agent file name. Start members
whose inputs are ready in a single message with `run_in_background: true`, and collect their
return values. Anything large goes through the member's output file, not the return value.
```

**Agent team** (only when the team tools are enabled and members must talk mid-task):

```text
Requires the experimental agent-team tools (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1). If they
are unavailable, use the subagent mechanics instead, add a reconcile step before integrate,
and say in the report that team coordination was unavailable.
- Form the team with TeamCreate (each member: name, agent file, role prompt). Register the
  work with TaskCreate, one task per independently checkable output, and state dependencies
  with depends_on.
- Members claim tasks, save their output to their file, and notify the leader. They request
  each other's results over SendMessage.
- The leader is notified when a member goes idle. It checks state with TaskGet, nudges or
  reassigns a stuck member, and corrects stale state with TaskUpdate.
- At finish: ask members to stop (SendMessage), then TeamDelete. Only one team is active per
  session, so tear down before any Agent call or a new TeamCreate.
```

**Hybrid:** state the mode per phase in the Phases table (add a `Mode` column), inline both
blocks above, and state the transition: a team phase ends with TeamDelete before the next
subagent phase, and its output files become that phase's inputs.

## SDD coordination

Use this when the project has an installed spec-driven development (SDD) system. The model — the
two-way handoff, the one-owner-per-phase rule, and the per-system coordination map — is in
`${CLAUDE_PLUGIN_ROOT}/shared/sdd-coordination.md`. This section turns it into three **addenda**
you splice into the template. The generated orchestrator cannot read
that shared file at runtime, so **inline the concrete values** from the detected system's
coordination row: `{system}`, `{owned-segment}`, `{ACTIVATE}` (its entry point), auto-invokable or
human-gated, `{HANDBACK_CONTRACT}` (the artifact paths that mark completion), and
`{WRITEBACK_RULE}`.

Mark every phase as either delegated (`→ SDD: {system}`) or orchestrator-owned, so no phase is done
twice. Reference the SDD's artifacts in place — never copy them into `_agents_workspace/`.

### Addendum 1 — phase 0 (context check): locate, then activate the spec
Add to the context-check step of phase 0 (intake & triage), reached only after triage routes the
request in as in-{domain} work, before going to prepare:

```
- If the active spec for this request does not yet exist under `{HANDBACK_CONTRACT}`, the SDD
  owns the next step. Activate it (hand-in):
  - Auto-invokable: invoke `{ACTIVATE}` with a contextual prompt built from the goal and the
    constraints this orchestrator already holds, so {system} starts without re-gathering.
  - Human-gated: emit that contextual prompt to the user, state how to run {system}'s step, and
    **pause** until the user confirms it is done.
- If the spec already exists, go straight to prepare and treat it as the input contract.
```

### Addendum 2 — prepare: read the contract, do not restate it
Add to the prepare phase:

```
- Read `{HANDBACK_CONTRACT}` as the authoritative input — requirements, design, tasks. Agents
  treat it as the source of truth; they do not re-derive requirements the SDD owns.
- Reference these artifacts by path; do not copy them into `_agents_workspace/`.
```

### Addendum 3 — integrate / finish: write status back in {system}'s conventions
Add to the integrate phase:

```
- The final deliverable goes to the user's target path as usual.
- Write status and decisions back into {system}: {WRITEBACK_RULE}. Never overwrite human-authored
  spec prose — the spec owns intent, the harness owns execution.
```

### Worked snippet — Spec Kit (auto-invokable)
- **owned-segment:** spec → plan → tasks · **ACTIVATE:** the specify flow / author `specs/<NNN>/`
- **HANDBACK_CONTRACT:** `specs/<NNN>/{spec,plan,tasks}.md` complete · **WRITEBACK_RULE:** tick the
  task checkboxes in `tasks.md`

```
### Phase 0: intake & triage  → SDD: GitHub Spec Kit
... triage (trivial/off-domain → answer and stop); then the context-check branch ...
- If `specs/<NNN>/tasks.md` for this request is absent, hand in to Spec Kit: run its specify flow
  with a contextual prompt from the goal + constraints; proceed once spec/plan/tasks exist.
### Phase 1: prepare
- Read `specs/<NNN>/{spec,plan,tasks}.md` as the contract; reference in place.
### Phase 3: integrate
- Write the deliverable; tick the completed checkboxes in `specs/<NNN>/tasks.md`.
```

### Worked snippet — AWS Kiro (human-gated, IDE)
- **ACTIVATE:** the user authors in the Kiro IDE · **HANDBACK_CONTRACT:**
  `.kiro/specs/<feature>/{requirements,design,tasks}.md`

```
### Phase 0: intake & triage  → SDD: AWS Kiro
- (triage first; for in-domain work:) If `.kiro/specs/<feature>/` is absent, emit a contextual prompt (goal + constraints + the EARS
  requirements to capture), tell the user to author it in Kiro, and **pause**. Resume when the
  files exist.
```

### Defer-heavy systems (BMAD, spec-workflow-mcp, Taskmaster)
These own a larger segment, but the protocol is identical — there is no "step aside" mode. Activate
the SDD's own flow with a contextual prompt, let it run its owned segment (personas, approval gate,
task loop), and have the orchestrator own only what the SDD does not: typically execution,
integration, and a cross-boundary QA pass over the SDD's output. When Taskmaster pairs with a spec
system, anchor requirements to the spec and route **task status** through `.taskmaster/tasks/tasks.json`.

## Tracker coordination

Use this when the project has an installed issue tracker. The model — the tracker as the
**work-state owner**, the phase-0 pull-or-create, the write-back, and the per-tracker command map —
is in `${CLAUDE_PLUGIN_ROOT}/shared/tracker-coordination.md`. This section turns it into three
**addenda** you splice into the template. The generated orchestrator
cannot read that shared file at runtime, so **inline the concrete values** from the detected
tracker's coordination row: `{tracker}`, `{READY_QUERY}` (its ready-work query), `{CREATE_CMD}`
(its create command), `{STATUS_WRITEBACK}` (its close/transition convention), and auto-invokable or
human-gated access.

Unlike an SDD system, a tracker does not own a phase — it owns the work-state **concern** that
brackets the run. Reference issues by ID; never copy issue content into `_agents_workspace/`, and
keep no parallel status file beside the tracker.

### Addendum T1 — phase 0 (context check): pull ready work, or create the issue
Add to the context-check step of phase 0 (intake & triage), reached only after triage routes the
request in as in-{domain} work:

```
- Check the tracker for a matching ready item: run `{READY_QUERY}`. If one matches this request,
  claim it and carry its ID through the run.
- If the work is new, create the issue first (`{CREATE_CMD}`), so {tracker} owns the work state
  from the start — then proceed with its ID.
- Human-gated access (no CLI/MCP configured): emit a contextual prompt stating what to file or
  look up, and **pause** until the user confirms.
```

### Addendum T2 — work: reference the issue, do not copy it
Add to the prepare/work phases:

```
- Carry the issue ID in the headers of workspace artifacts (`issue: {tracker-id}`); read the
  issue in place when context is needed.
- Do not copy issue content into `_agents_workspace/`, and keep no status file of your own —
  {tracker} is the single owner of work state.
```

### Addendum T3 — integrate / finish: write status back in {tracker}'s conventions
Add to the integrate phase:

```
- The final deliverable goes to the user's target path as usual.
- Write status back: {STATUS_WRITEBACK}, referencing the deliverable's path. Never delete issues
  and never rewrite human-authored issue prose — the tracker owns intent and history, the
  harness owns execution.
```

### Addendum T4 — integrate / finish: tracker-sync write-through (dual-tracker projects only)
Splice this **only when the project has the generated `tracker-sync` skill** — a repo-native
tracker plus a human SaaS tracker, with the sync artifacts generated per
`${CLAUDE_PLUGIN_ROOT}/shared/tracker-sync-protocol.md`. Add immediately after Addendum T3's
write-back:

```
- After {STATUS_WRITEBACK} completes, invoke the `tracker-sync` skill in **scoped** mode for the
  item(s) touched this run, so the human tracker's projection reflects the new work state.
  Scoped mode pushes only those items — it runs no intake and no reconcile.
- If the sync run fails or its preflight stops it, note that in the run summary and continue —
  the deliverable does not depend on the projection, and a later `full` run catches up.
```

### Worked snippet — Beads (auto-invokable)
- **READY_QUERY:** `bd ready --json` · **CREATE_CMD:** `bd create "title"` ·
  **STATUS_WRITEBACK:** `bd update {id} --claim` on start, `bd close {id} "summary"` on completion

```
### Phase 0: intake & triage
... triage (trivial/off-domain → answer and stop); then the context-check branch ...
- Run `bd ready --json`; if an item matches this request, claim it (`bd update {id} --claim`)
  and carry the ID. If the work is new, `bd create "title"` first.
### Phase 3: integrate
- Write the deliverable; `bd close {id} "done — see {deliverable path}"`.
```

### Composing with an SDD system
When both an SDD system and a tracker are present, the SDD addenda own *what to build* (spec,
plan, decomposition) and the tracker addenda own *work state* (ready, in progress, done) — splice
both, and give each item's status exactly one owner. When Taskmaster is present, spec-derived
tasks route their status through `.taskmaster/tasks/tasks.json`, general issues through the
tracker — never mirror one item's state in both (see the Taskmaster boundary in
`${CLAUDE_PLUGIN_ROOT}/shared/tracker-coordination.md`).

## Authoring rules

1. State the execution mode at the top and inline exactly one mechanics block (both for hybrid,
   plus a `Mode` column in the Phases table).
2. Every phase row names its owner, what it reads, what it writes, and a checkable "done when".
   The steps inside a phase are left to the model, except the fragile sequences already written
   out (archive, teardown, write-back).
3. Use clear paths under `_agents_workspace/`; avoid ambiguous relative paths.
4. Keep the failure policy realistic: do not assume everything succeeds.
5. Include at least one normal and one error test scenario.
6. When an SDD system and/or issue tracker is present, splice in the matching
   [SDD coordination](#sdd-coordination) / [Tracker coordination](#tracker-coordination) addenda
   with the system's concrete values inlined. Mark each phase as delegated or orchestrator-owned,
   and give each item's work state exactly one owner.

## Follow-up keywords

The description opens by asserting the orchestrator is the repo's entry point for {domain} work —
that framing is what makes the skill trigger broadly rather than only on a narrow initial phrasing.
It is the description's job to back the `CLAUDE.md` entry-point directive, not just to advertise the
initial run.

Initial-run keywords alone leave the harness unused after its first run. Put follow-up
phrasings in the description: re-run, run again, update, modify, supplement; "only the
{part} again"; "based on the previous result", "improve the result"; and everyday domain
requests (for a launch-planning harness: "launch", "promotion", and the like).
