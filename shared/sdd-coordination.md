# SDD coordination

The spec-process instance of the harness coordination protocol. The protocol itself — the
two-way handoff (activate, owned segment, hand-back, write-back), auto-invokable vs human-gated
activation, and the two rules (**one owner per phase**, **one source of truth per artifact**) —
is in `${CLAUDE_PLUGIN_ROOT}/shared/coordination-protocol.md`; read it first. This file applies
it to spec-driven development (SDD) systems: an SDD system owns a **bounded segment** of the
workflow — usually the spec/plan/decompose front-end, and for the heavier systems part of the
build too — and the per-system map below gives the concrete values `harness-setup` inlines into
the generated orchestrator. Detection of which system is present is a separate concern: see
`${CLAUDE_PLUGIN_ROOT}/shared/detection-signatures.md`.

## Per-system coordination map

The owned segment, the activation entry point, the hand-back contract, and the write-back rule for
each system in the curated shortlist. `harness-setup` looks up the detected system's row and inlines
these concrete values into the orchestrator. Where a system spans versions (BMAD), the artifact path
follows the detected version — see `${CLAUDE_PLUGIN_ROOT}/shared/detection-signatures.md`.

| System | SDD owns | Activate (hand-in) | Auto-invokable? | Hand-back contract | Orchestrator writes back |
|---|---|---|---|---|---|
| **GitHub Spec Kit** | spec → plan → tasks | run the specify flow / author `specs/<NNN>/` from the contextual prompt | semi (CLI scaffolds; content authored) | `specs/<NNN>/{spec,plan,tasks}.md` present and complete | tick task checkboxes in `tasks.md` |
| **OpenSpec** | the change proposal | author `openspec/changes/<id>/` from the context | semi | the settled change proposal | implement the change; archive to `openspec/specs/` |
| **Agent OS** | the spec, honoring standards | produce `agent-os/specs/` per `standards/` | semi | the spec is ready | execute per spec + standards |
| **AWS Kiro** | EARS requirements/design/tasks (IDE) | emit the contextual prompt; the user authors in the Kiro IDE; **pause** | no (IDE / human) | `.kiro/specs/<feature>/{requirements,design,tasks}.md` | status back into `tasks.md` |
| **ADR tooling** | decision records | on a design decision, hand in "record this decision" | semi | an ADR file under `docs/adr/` | append an ADR for each decision the harness makes |
| **BMAD-METHOD** | the agile persona pipeline | activate the BMAD flow with the contextual prompt (which epic / story) | yes (CLI; human-in-loop steps) | `_bmad-output/` (v6) or `docs/{prd,architecture,stories}/` (v4) + story status | coordinate; add only the cross-cutting QA / integration BMAD lacks; write story status back |
| **spec-workflow-mcp** | the spec workflow + approval gate | call its MCP tools with the contextual prompt; wait on the approval gate | yes (MCP) + human approval | the approved spec under `.spec-workflow/specs/` | execute the approved spec; status back via its conventions |
| **Taskmaster** | task decomposition + tracking | hand in the PRD / context → it parses to a task graph | yes (CLI / MCP) | `.taskmaster/tasks/tasks.json` | execute tasks; update task status via Taskmaster |

The heavier systems (BMAD, spec-workflow-mcp, Taskmaster) own a **larger** segment and may be
human-gated, but the handoff protocol is the same — there is no "step aside and let the SDD own
everything" mode. The orchestrator always drives the parts the SDD does not own (typically
execution, integration, and a cross-boundary QA pass), and coordinates the rest.

### Taskmaster as a pairing

Taskmaster decomposes and tracks tasks; it **pairs** with an upstream spec system rather than
replacing one (it owns the task graph, not the requirements). When Taskmaster co-exists with a spec
system, the orchestrator anchors requirements to the spec system and routes **task status** through
Taskmaster's `tasks.json` instead of inventing its own status file — one owner per concern.

## How `harness-setup` uses this

1. After detecting the present system (Step 0), look up its row above and capture the **coordination
   context**: `{system, version, owned-segment, activation, auto-invokable, hand-back contract,
   write-back rule}`.
2. With the user, decide which phases the orchestrator delegates vs owns, and whether activation is
   auto or prompt-and-pause (Step 2). Fold the decision into the change manifest.
3. Splice the **SDD-coordination block** from `harness-setup`'s `references/orchestrator-template.md`
   into the chosen template (A / B / C), substituting the concrete values from the coordination
   context (Step 5). The generated orchestrator must be self-contained — inline the paths and the
   entry point; do not leave it pointing at this file.
4. Record the relationship in the `CLAUDE.md` pointer's **Spec process** line — see
   `${CLAUDE_PLUGIN_ROOT}/shared/claude-md-pointer.md`.
