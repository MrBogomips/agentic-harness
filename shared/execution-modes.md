# Execution modes

A harness coordinates more than one agent. There are three ways to run that coordination.
Pick one per harness — or, in hybrid, one per phase — and state the choice explicitly in
the orchestrator.

## Before you choose: the team-tools caveat

The agent-team mode depends on experimental tools: `TeamCreate`, `SendMessage`,
`TaskCreate`/`TaskUpdate`, `TeamDelete`. These are **not guaranteed to be available** in a
given Claude Code build, session, or permission setup. Treat their presence as a runtime
fact to check, not an assumption.

Because of that, every team-mode harness must define a **subagent fallback**. The subagent
mode uses only the `Agent` tool, which is broadly available. A harness that can only run as
a team is brittle; a harness that prefers a team and falls back to subagents is not. Build
the fallback at the same time as the team path, not later.

When the team tools are missing, do not fail — re-route to the subagent equivalent
(`Agent` with `run_in_background`) and note in the run that team coordination was
unavailable. The mapping below makes that re-route mechanical.

## The three modes

| Mode | Use when | Mechanism |
|------|----------|-----------|
| **Agent team** (default) | Two or more agents collaborate and benefit from real-time exchange — sharing findings, challenging each other, reconciling conflicts | Members run as peers; coordinate via `TeamCreate` + `SendMessage` + a shared task list (`TaskCreate`/`TaskUpdate`) |
| **Subagent** (fallback and lightweight default) | A single agent's work, or several independent jobs where only the result matters and inter-agent talk would be overhead | The orchestrator calls the `Agent` tool directly; parallelize with `run_in_background` and collect return values |
| **Hybrid** | Phases differ in character — e.g. independent collection, then consensus integration | Choose the mode per phase; state each phase's mode in the orchestrator |

The team mode is the *preferred* default when agents genuinely need to talk: cross-checking
and shared discovery raise quality in a way isolated subagents cannot. But "preferred" is
conditional on the tools being present and on the work actually needing coordination. When
either is false, subagents are the right call, not a downgrade.

## Decision order

1. Is this a single agent? → **subagent**. One agent needs no team.
2. Two or more agents: do they need to exchange information mid-task (challenge findings,
   resolve conflicts, hand off partial state)? → if yes, **agent team**; if no — only the
   final results combine — **subagent** is enough and cheaper.
3. Are the team tools unavailable? → **subagent fallback**, using the mapping below.
4. Do phases differ markedly in whether coordination helps? → **hybrid**, mode stated per
   phase.

## Team-to-subagent fallback mapping

When team mode is unavailable, translate it mechanically:

| Team-mode mechanism | Subagent equivalent |
|---------------------|---------------------|
| `TeamCreate` + member prompts | One `Agent` call per member, each with its role prompt |
| Parallel members | `Agent` calls with `run_in_background: true`, collected after |
| `SendMessage` between members | No direct channel — members can't talk; route shared context through files the orchestrator writes and each agent reads |
| `TaskCreate`/`TaskUpdate` shared list | The orchestrator holds the task list itself and assigns work in the spawn prompts |
| Leader synthesis after team | Orchestrator reads each agent's output file/return value and integrates |

The cost of the fallback is real: subagents cannot debate or revise each other mid-flight.
Where the team relied on that, compensate by adding an explicit integration or review step
that reconciles the independent outputs afterward.

## Data-passing per mode

State the data-passing method inside the orchestrator. Match it to the mode:

| Method | How | Mode | Fits |
|--------|-----|------|------|
| Message-based | direct member-to-member via `SendMessage` | team | real-time coordination, lightweight state hand-off |
| Task-based | shared work state via `TaskCreate`/`TaskUpdate` | team | progress tracking, dependency management |
| File-based | write and read files at agreed paths | team + subagent | large or structured deliverables, audit trail |
| Return-value-based | the `Agent` tool's return message | subagent | the orchestrator collects results directly |

- **Team mode:** task-based for coordination + file-based for deliverables + message-based
  for live exchange.
- **Subagent mode:** return-value-based for results + file-based for anything large.
- **Hybrid:** apply the matching combination per phase, and check the hand-off at phase
  boundaries — when a team phase feeds a subagent phase, the team's output files become the
  subagent's inputs.

### File-passing convention

- Keep intermediate work under a `_agents_workspace/` directory in the working tree.
- Name files `{phase}_{agent}_{artifact}.{ext}` — e.g. `01_analyst_requirements.md`.
- Write only the final deliverable to the user's target path; preserve `_agents_workspace/` for
  later inspection rather than deleting it.
