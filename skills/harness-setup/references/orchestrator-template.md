# Orchestrator template

The orchestrator is the top-level skill that coordinates the whole team. It comes in three
shapes, one per execution mode. Pick the shape from the mode chosen in Step 2; for hybrid,
state the mode per phase.

## Table of contents

- [Orchestrator template](#orchestrator-template)
  - [Table of contents](#table-of-contents)
  - [Template A — agent team (default)](#template-a--agent-team-default)
  - [Template B — subagent (fallback / lightweight)](#template-b--subagent-fallback--lightweight)
  - [Template C — hybrid](#template-c--hybrid)
  - [SDD coordination](#sdd-coordination)
  - [Tracker coordination](#tracker-coordination)
  - [Authoring rules](#authoring-rules)
  - [Follow-up keywords](#follow-up-keywords)

---

## Template A — agent team (default)

The first choice when two or more agents need to talk while they work. Build the team with
`TeamCreate`; coordinate over a shared task list and `SendMessage`.

> If the project has an installed SDD system and/or issue tracker, also splice in the matching
> [SDD coordination](#sdd-coordination) addenda (phase 0, prepare, integrate) and/or
> [Tracker coordination](#tracker-coordination) addenda (phase 0, work, integrate), so the
> orchestrator hands work to the spec process and keeps the tracker as the work-state owner.

````markdown
---
name: {domain}-orchestrator
description: "Entry point for all {domain} work in this repo — invoke before responding to any {domain} request. Coordinates the {domain} agent team to produce {deliverable}. {initial keywords}. Also use for follow-ups: re-run, update, modify, supplement, improve the previous result, and everyday {domain} requests."
model: inherit
---

# {Domain} orchestrator

Coordinates the {domain} agent team to produce {final deliverable}.

## Execution mode: agent team

## Team

| Member | Type | Role | Skill | Output |
|--------|------|------|-------|--------|
| {member-1} | {custom or built-in} | {role} | {skill} | {file} |
| {member-2} | ... | ... | ... | ... |

## Workflow

### Phase 0: intake & triage  (always entered first — this skill is the repo entry point)
This skill is the repo's entry point, so it runs for *every* prompt. Triage before doing anything else:
- Trivial, conversational, or clearly outside {domain} → answer it directly (or take the obviously
  small correct action) and stop. Do not form a team or open `_agents_workspace/`.
- In-{domain} work → run the context check, then continue into the workflow.

**Context check** (in-{domain} work only) — branch on whether prior work exists:
- `_agents_workspace/` absent → initial run; go to Phase 1.
- `_agents_workspace/` present + a partial-change request → partial re-run; re-invoke only
  the affected member and overwrite only its output.
- `_agents_workspace/` present + new input → new run; move the old `_agents_workspace/` to
  `_agents_workspace/archive/{YYYYMMDD_HHMMSS}/`, then go to Phase 1.
On a partial re-run, pass the prior output path into the member's prompt so it reads the
existing result and folds in the change.

### Phase 1: prepare
1. Read the input and identify {what to identify}.
2. Create `_agents_workspace/` (or recreate it after archiving the old one on a new run).
3. Save the input under `_agents_workspace/00_input/`.

### Phase 2: form the team
1. `TeamCreate(team_name, members: [...])` — each member with its name, type, model, and a
   role prompt.
2. `TaskCreate(tasks: [...])` — roughly five to six tasks per member; declare dependencies
   with `depends_on`.

### Phase 3: {the main work}
Members claim tasks from the shared list and work independently. State the communication
rules: who passes what to whom via `SendMessage`; that each member saves its output to a
file and notifies the leader on completion; that a member requesting another's result asks
over `SendMessage`. The leader watches progress (it is notified when a member goes idle),
nudges or reassigns a stuck member, and checks state with `TaskGet`.

| Member | Output path |
|--------|-------------|
| {member-1} | `_agents_workspace/{phase}_{member-1}_{artifact}.md` |

### Phase 4: integrate
1. Wait for all tasks to complete (`TaskGet`).
2. Read each member's output.
3. Apply the integration logic; where members conflict, record both with their sources.
4. Write the final deliverable to the user's target path.

### Phase 5: tear down
1. Ask members to stop (`SendMessage`); `TeamDelete`.
2. Keep `_agents_workspace/` (do not delete intermediate work).
3. Report a summary to the user.

## Error handling

| Situation | Strategy |
|-----------|----------|
| One member fails or stalls | leader checks via `SendMessage`, restarts or replaces it |
| Most members fail | tell the user, confirm whether to continue |
| Timeout | use the partial results, stop the unfinished members |
| Members disagree | record both with sources; do not delete either |
| Task state lags | leader confirms with `TaskGet`, corrects with `TaskUpdate` |

## Test scenarios
- **Normal:** input → analysis → team of N + M tasks → self-coordinated work → integration →
  teardown → the deliverable exists at its path.
- **Error:** a member stops mid-phase → leader gets the idle notice → restart attempt →
  on repeated failure, reassign its task → integrate the rest → note the gap in the report.
````

## Template B — subagent (fallback / lightweight)

When team communication is unnecessary, or the team tools are unavailable. Spawn each agent
with the `Agent` tool and collect return values.

> If the project has an installed SDD system and/or issue tracker, also splice in the matching
> [SDD coordination](#sdd-coordination) and/or [Tracker coordination](#tracker-coordination) addenda.

````markdown
---
name: {domain}-orchestrator
description: "Entry point for all {domain} work in this repo — invoke before responding to any {domain} request. Coordinates {domain} agents to produce {deliverable}. {initial keywords} + follow-up keywords."
model: inherit
---

## Execution mode: subagent

## Agents

| Agent | subagent_type | Role | Skill | Output |
|-------|---------------|------|-------|--------|
| {agent-1} | {built-in or custom} | {role} | {skill} | {file} |

## Workflow

### Phase 0: intake & triage  (always entered first — this skill is the repo entry point)
Same as Template A: triage every prompt first — trivial / conversational / out-of-{domain} → answer
directly and stop; in-{domain} work → run the context check (branch on whether `_agents_workspace/`
exists) and continue.

### Phase 1: prepare
Read the input; create `_agents_workspace/` (archiving any old one on a new run).

### Phase 2: run in parallel
Invoke the agents in a single message:

| Agent | Input | Output | model | run_in_background |
|-------|-------|--------|-------|-------------------|
| {agent-1} | {source} | `_agents_workspace/{phase}_{agent}_{artifact}.md` | {model} | true |

### Phase 3: integrate
Collect each return value; read file outputs; apply the integration logic; write the final
deliverable.

### Phase 4: finish
Keep `_agents_workspace/`; report a summary.

## Error handling
- One agent fails: retry once; on a second failure, note the omission and continue.
- Most fail: tell the user and confirm.
- Timeout: use the partial results.
````

## Template C — hybrid

A different mode per phase. State `**Execution mode:** {team | subagent}` at the top of each
phase.

> If the project has an installed SDD system and/or issue tracker, the
> [SDD coordination](#sdd-coordination) and/or [Tracker coordination](#tracker-coordination)
> addenda attach to whichever phases own the context check, the prepare step, and the integrate
> step — regardless of each phase's execution mode.

````markdown
---
name: {domain}-orchestrator
description: "Entry point for all {domain} work in this repo — invoke before responding to any {domain} request. {domain} orchestrator (hybrid). {keywords} + follow-up keywords."
model: inherit
---

## Execution mode: hybrid

| Phase | Mode | Why |
|-------|------|-----|
| Phase 0 (intake & triage) | — | gate every prompt; short-circuit trivial / off-domain |
| Phase 2 (parallel collection) | subagent | independent collection, no coordination needed |
| Phase 3 (consensus integration) | agent team | reconcile conflicting inputs by discussion |
| Phase 4 (independent verification) | subagent | one QA agent verifies objectively |

### Phase 0: intake & triage  (always entered first — this skill is the repo entry point)
Same as Template A: triage every prompt first — trivial / conversational / out-of-{domain} → answer
directly and stop; in-{domain} work → run the context check and continue into the phases below.

### Phase 2: collect — **Execution mode:** subagent
Invoke N agents in parallel (`run_in_background: true`); save each to
`_agents_workspace/02_{agent}_raw.md`.

### Phase 3: integrate — **Execution mode:** agent team
`TeamCreate` an integration team; `TaskCreate` work that reads the Phase 2 files; members
reconcile conflicts via `SendMessage`; write `_agents_workspace/03_integrated.md`;
`TeamDelete`.

### Phase 4: verify — **Execution mode:** subagent
One QA subagent reads `_agents_workspace/03_integrated.md` and writes a verification report.
````

**Transition rules.** Team → subagent: `TeamDelete` before any `Agent` call. Subagent →
team: pass the subagent's file outputs to members as read paths. Team → team: tear down the
old team before the next `TeamCreate` (only one team is active per session).

## SDD coordination

Use this when the project has an installed spec-driven development (SDD) system. The model — the
two-way handoff, the one-owner-per-phase rule, and the per-system coordination map — is in
`${CLAUDE_PLUGIN_ROOT}/shared/sdd-coordination.md`. This section turns it into three **addenda**
you splice into whichever template you picked (A / B / C). The generated orchestrator cannot read
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
Add to the integrate (team) or finish (subagent) phase:

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
### Phase 4: integrate
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
**addenda** you splice into whichever template you picked (A / B / C). The generated orchestrator
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
Add to the integrate (team) or finish (subagent) phase:

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
### Phase 4: integrate
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

1. State the execution mode at the top. For hybrid, a per-phase mode table is required.
2. For team mode, be concrete about `TeamCreate` / `TaskCreate` / `SendMessage` usage.
3. For subagent mode, fully specify each `Agent` call (name, type, prompt, model,
   `run_in_background`).
4. Use clear paths under `_agents_workspace/`; avoid ambiguous relative paths.
5. State inter-phase dependencies — which phase needs which phase's output. For hybrid,
   call out the transition points.
6. Make error handling realistic — do not assume everything succeeds.
7. Include at least one normal and one error test scenario.
8. When an SDD system and/or issue tracker is present, splice in the matching
   [SDD coordination](#sdd-coordination) / [Tracker coordination](#tracker-coordination) addenda
   with the system's concrete values inlined; mark each phase as delegated or orchestrator-owned,
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
