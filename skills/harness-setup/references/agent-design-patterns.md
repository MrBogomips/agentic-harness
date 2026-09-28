# Agent design patterns

How to structure a team, which architecture pattern fits the work, when to split a role
into its own agent, and the shape of an agent definition file.

## Table of contents

1. [Execution modes, in brief](#1-execution-modes-in-brief)
2. [The six architecture patterns](#2-the-six-architecture-patterns)
3. [Composite patterns](#3-composite-patterns)
4. [Agent type selection](#4-agent-type-selection)
5. [Splitting vs merging agents](#5-splitting-vs-merging-agents)
6. [Skill vs agent](#6-skill-vs-agent)
7. [Agent definition template](#7-agent-definition-template)

---

## 1. Execution modes, in brief

Two modes, with a third that mixes them. The full decision logic, the experimental
team-tools caveat, and the team-to-subagent fallback mapping are in the shared execution-modes
doc — read that before designing the team. The short version:

- **Agent team** — members run as peers and coordinate directly (`SendMessage`) over a
  shared task list (`TaskCreate`). Use it when agents need to exchange information while they
  work: sharing findings, challenging each other, reconciling conflicts. Only one team is
  active per session, but a team can be disbanded between phases and a new one formed. The
  team tools are experimental and off unless `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, so
  always design a subagent fallback.
- **Subagent** (the default) — the orchestrator spawns each agent with the `Agent` tool; the
  agent returns its result and does not talk to siblings. Use it for a single agent, or for independent
  jobs where only the combined result matters. Parallelize with `run_in_background`.

Each pattern below notes whether a team earns its cost or a subagent is the better fit.

## 2. The six architecture patterns

### Pipeline

Stages run in order; each consumes the previous stage's output.

```
[Analyze] → [Design] → [Build] → [Verify]
```

Fits work with strong sequential dependency. A slow stage stalls the whole line, so make
each stage as independent as the work allows. Team mode adds little to a pure sequence —
unless a stage has parallel sub-work, in which case a team helps there.

### Fan-out / Fan-in

Independent work in parallel, then integration.

```
            ┌→ [Specialist A] ─┐
[Distribute]┼→ [Specialist B] ─┼→ [Integrate]
            └→ [Specialist C] ─┘
```

Fits when one input needs several independent perspectives. The integration stage governs
final quality. This is the most natural fit for a team: members surface findings to each
other and one member's discovery can redirect another's work mid-flight, which a set of
isolated subagents cannot do. Build it as a team when the tools are enabled.

### Expert Pool

Route to the one specialist the input needs.

```
[Router] → { Specialist A | Specialist B | Specialist C }
```

Fits when different input types need different handling. The router's classification is the
weak point. Subagents usually fit better — only the chosen specialist runs, so a standing
team is wasted.

### Producer–Reviewer

A producer and a reviewer work as a pair, looping until the deliverable passes.

```
[Produce] → [Review] → (issues?) → back to [Produce]
```

Fits when quality matters and there are objective review criteria. Cap the retry count (two
or three) to avoid an endless loop. A team lets producer and reviewer exchange feedback
directly; subagents work too when a written review hand-off is enough.

### Supervisor

A central agent holds the work state and hands out work as it goes.

```
              ┌→ [Worker A]
[Supervisor] ─┼→ [Worker B]
              └→ [Worker C]
```

Fits variable workloads where assignment is decided at runtime, not fixed up front (the
difference from fan-out). Keep delegation units large enough that the supervisor is not the
bottleneck. The team's shared task list matches this naturally: register work, let members
claim it.

### Hierarchical Delegation

A higher agent decomposes a problem and delegates to lower agents, recursively.

```
[Lead] → [Sub-lead A] → [Worker A1], [Worker A2]
       → [Sub-lead B] → [Worker B1]
```

Fits problems that decompose cleanly into a tree. Keep it to two levels — three or more adds
latency and loses context. Teams cannot nest (a member cannot form its own team), so
implement level one as a team and level two as subagents, or flatten to a single team.

## 3. Composite patterns

Real harnesses usually combine patterns:

| Composite | Shape | Example domain |
|-----------|-------|----------------|
| Fan-out + Producer–Reviewer | parallel production, then per-item review | translate several variants in parallel, each reviewed separately |
| Pipeline + Fan-out | parallelize one stage of a sequence | sequential analysis → parallel build → sequential integration test |
| Supervisor + Expert Pool | supervisor routes to the right specialist on demand | inbound triage that assigns each case to a domain specialist |

Use a team for the stages whose members benefit from talking (when the tools are enabled), and
subagents for stages that are isolated.

## 4. Agent type selection

Pass the type via the `Agent` tool's `subagent_type`. Built-in types:

| Type | Tool access | Fits |
|------|-------------|------|
| `general-purpose` | full (incl. web, scripts) | research, validation, any work needing tools |
| `Explore` | read-only | reading and analyzing a codebase |
| `Plan` | read-only | design and planning |

A custom type is an agent you defined under `.claude/agents/{name}.md`, invoked with
`subagent_type: "{name}"`; it has full tool access. Choose by:

| Situation | Choice |
|-----------|--------|
| Complex role reused across sessions | custom type (a file) |
| Simple collection where a prompt suffices | `general-purpose` + a detailed prompt |
| Read-only analysis or review | `Explore` |
| Design or planning only | `Plan` |
| Work that modifies files | custom type |

Whatever the type, write the agent as a file (see the harness model's file rule). For a QA
agent specifically, use `general-purpose` — `Explore` cannot run validation.

## 5. Splitting vs merging agents

Judge along four axes:

| Axis | Split when | Merge when |
|------|------------|------------|
| Expertise | the domains differ | the domains overlap |
| Parallelism | they can run independently | they are sequentially dependent |
| Context | the context load is large | both are light and fast |
| Reusability | other teams use it too | only this team uses it |

Prefer a few focused agents over many thin ones — coordination cost rises with team size.

## 6. Skill vs agent

| Aspect | Skill | Agent |
|--------|-------|-------|
| What it is | procedural knowledge + tools | an expert persona + principles |
| Lives in | `.claude/skills/` | `.claude/agents/` |
| Triggered by | matching a request | explicit invocation via the `Agent` tool |
| Size | small to large (a workflow) | small (a role) |
| Answers | *how* | *who* |

An agent leverages a skill in one of three ways:

| Way | How | Fits |
|-----|-----|------|
| Preload | list the skill under `skills:` in the agent's frontmatter; its full content is injected when the agent starts | a skill the agent needs on every run |
| Skill invocation | the agent prompt says to invoke `/skill-name` via the Skill tool | a skill the agent needs only for some inputs |
| Inline | the skill content sits inside the agent definition | short (≤50 lines), exclusive to that agent |
| Reference load | the agent reads a `references/` file when needed | large, only conditionally relevant content |

## 7. Agent definition template

An agent file carries what the model cannot infer: the role's goal, the quality bar, the
contract with its neighbours, and the reasons behind its constraints. It does not carry a
procedure. The model plans its own steps, and the procedure belongs in a skill. Failure
handling lives once, in the orchestrator, so do not add per-agent error or timeout sections.

```markdown
---
name: agent-name
description: "One or two sentences on the role and when the orchestrator should spawn it."
model: inherit
effort: high            # judgment roles high/xhigh; reading/collection roles low/medium
skills:                 # preloaded on start — skills this agent always needs
  - skill-name
---

# Agent name — one-line role

{What this agent is for in this project, and who uses its output. One short paragraph of
context: the domain, the audience, what "good" looks like here.}

## Responsibilities
- {what it owns — and, where it helps, what it deliberately does not}

## Contract
- Input: {path or source, and what it contains}
- Output: {path, format, and structure}
- Done when: {the checkable condition that makes the output complete}

## Constraints
- {a real constraint, with its reason}

## Team communication   (team mode only)
- Receives from / sends to / claims: {who, what}
```

Default `model` to `inherit` and tune the role with `effort`, as described in the harness-setup
Model and effort paragraph. Set an alias (`opus`, `sonnet`, `haiku`) only when the role must
differ from the session model. Do not pin a full model id: it fixes one release and ages with it.
