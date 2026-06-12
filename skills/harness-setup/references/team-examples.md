# Team examples

Worked examples across generic domains. Each shows the architecture pattern, the execution
mode, the agent composition, and the coordination shape. Adapt them — do not copy them
literally.

## Table of contents

- [Team examples](#team-examples)
  - [Table of contents](#table-of-contents)
  - [1. Multi-source research (team, fan-out/fan-in)](#1-multi-source-research-team-fan-outfan-in)
  - [2. Long-form authoring (team, pipeline + fan-out)](#2-long-form-authoring-team-pipeline--fan-out)
    - [A full agent file — `consistency-reviewer.md`](#a-full-agent-file--consistency-reviewermd)
  - [3. Generate-and-review (subagent, producer–reviewer)](#3-generate-and-review-subagent-producerreviewer)
  - [4. Code review (team, fan-out/fan-in + debate)](#4-code-review-team-fan-outfan-in--debate)
  - [5. Large migration (team, supervisor)](#5-large-migration-team-supervisor)
  - [What every example shares](#what-every-example-shares)

---

## 1. Multi-source research (team, fan-out/fan-in)

Several researchers cover different source types in parallel; the leader integrates.

| Member | Type | Scope | Output |
|--------|------|-------|--------|
| primary-source-researcher | general-purpose | official / first-party sources | `research_primary.md` |
| press-researcher | general-purpose | reporting and analysis | `research_press.md` |
| community-researcher | general-purpose | forums and social discussion | `research_community.md` |
| context-researcher | general-purpose | background, comparables, prior art | `research_context.md` |
| (leader = orchestrator) | — | integrate into one report | `synthesis-report.md` |

The researchers use the `general-purpose` built-in type but are still defined as files —
each file states the scope and the team communication protocol so the roles are reusable and
the collaboration has a contract.

Coordination: the four work independently, but pass relevant finds to each other over
`SendMessage` (the press researcher hands an acquisition rumor to the context researcher;
the community researcher flags a press item to the press researcher). Conflicting claims are
debated directly and, in the final report, recorded side by side with their sources. This
cross-talk is why it is a team rather than four isolated subagents.

## 2. Long-form authoring (team, pipeline + fan-out)

A document built in stages, with parallel groundwork.

```text
Phase 1 (team, parallel):  structure-planner + source-curator + outline-builder
                           — keep each other consistent via SendMessage
Phase 2 (subagent):        section-writer drafts from the Phase 1 outputs
Phase 3 (team, parallel):  fact-checker + consistency-reviewer review the draft
                           — share findings via SendMessage
Phase 4 (subagent):        section-writer revises to reflect the review
```

Phase 1 forms a team, then tears it down. Phase 2 needs no team (one writer working alone),
so it runs as a subagent reading the Phase 1 files from `_agents_workspace/`. Phase 3 forms a
new review team (only one team is active at a time, but Phase 1's was already disbanded).
Phase 4 is again a lone subagent.

### A full agent file — `consistency-reviewer.md`

```markdown
---
name: consistency-reviewer
description: "Checks a long-form draft for internal consistency — terminology, claims, and cross-references that contradict each other."
model: inherit
---

# Consistency reviewer

You check a draft for internal contradictions. You do not judge prose quality — that is the
writer's concern. You judge whether the document agrees with itself.

## Core role
1. Flag terms used with two different meanings.
2. Flag claims in one section that a later section contradicts.
3. Flag cross-references that point to the wrong place or to nothing.

## Working principles
- Report file and location for every issue, so the writer can act without searching.
- Distinguish a true contradiction from a stylistic variation; report only the former.

## Input / output protocol
- Input: the draft at `_agents_workspace/02_section-writer_draft.md`.
- Output: `_agents_workspace/03_consistency_report.md`.
- Format: one entry per issue — location, the two conflicting statements, suggested fix.

## Team communication protocol
- To fact-checker: SendMessage when a consistency issue depends on a factual question.
- To the leader: a report distinguishing confirmed issues from open questions.

## Error handling
- If the draft is missing, report that and stop rather than inventing content.

## Collaboration
- Works alongside fact-checker; the two divide internal vs external correctness.
```

## 3. Generate-and-review (subagent, producer–reviewer)

Two agents — a producer and a reviewer — looping until the output passes. With only two
agents and a hand-off that matters more than conversation, subagent mode fits; cap the loop
at two or three rounds.

| Agent | subagent_type | Role |
|-------|---------------|------|
| asset-producer | custom | generate the batch of outputs |
| asset-reviewer | custom | inspect each, mark PASS / FIX / REDO |

The reviewer judges on objective criteria (completeness, consistency, legibility), not
taste, and writes a per-item verdict with a specific fix instruction. Items marked REDO go
back to the producer with that instruction; after the retry cap, a still-failing item is
passed with a warning. If a large fraction needs REDO, the reviewer proposes revising the
generation prompt rather than looping further.

## 4. Code review (team, fan-out/fan-in + debate)

Reviewers with different lenses examine the same change and talk to each other directly.

```text
[leader] → TeamCreate(review-team)
    ├── security-reviewer:    vulnerabilities, input handling, authz
    ├── performance-reviewer: hot paths, query patterns, allocations
    └── test-reviewer:        coverage and meaningful assertions
    → reviewers cross-message; leader synthesizes
```

The value is in the cross-talk: the security reviewer flags an injectable query and asks the
performance reviewer to weigh in; the performance reviewer finds an N+1 query and asks the
test reviewer whether a test would have caught it. Reviewers reach each other without routing
through the leader, which catches cross-domain issues a set of siloed reviews would miss.

## 5. Large migration (team, supervisor)

A supervisor analyzes the file set and hands out batches dynamically.

```text
[supervisor] → analyze file list → register batches as tasks
    ├→ migrator-1 (claims a batch)
    ├→ migrator-2 (claims a batch)
    └→ migrator-3 (claims a batch)
    ← on completion, claims the next; on failure, supervisor diagnoses and reassigns
```

Unlike fan-out, batches are not fixed in advance — workers claim the next item from the
shared task list as they free up, which keeps fast workers busy and lets the supervisor
rebalance around failures. When all batches are done, the supervisor runs the integration
test.

## What every example shares

- Every agent is a file under `.claude/agents/`, with the required sections and — in team
  mode — a team communication protocol.
- Skills live under `.claude/skills/{name}/SKILL.md`.
- The orchestrator names the agents and the workflow and states the execution mode. See
  `references/orchestrator-template.md`.
