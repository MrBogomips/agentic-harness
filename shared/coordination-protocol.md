# Coordination protocol

When a project has a **process layer** installed — a spec-driven development (SDD) system, an
issue tracker — the harness does not run beside it: the two **work coordinated**. This file
defines the generic protocol every coordination follows; the per-area instance files apply it
to concrete systems:

- `${CLAUDE_PLUGIN_ROOT}/shared/sdd-coordination.md` — the spec process (SDD systems)
- `${CLAUDE_PLUGIN_ROOT}/shared/tracker-coordination.md` — issue tracking

A future process area adds an **instance file** with its per-system map; it does not add new
protocol prose here. `harness-setup` reads the protocol and the instance maps at generation
time; the generated orchestrator cannot read these files at runtime, so the relevant values
are **inlined** when the orchestrator is generated.

A harness is the *who/how/when* of the work — agents, skills, order. A process layer is part of
the *project process* the work follows — what to build, what work is ready and in what state.
They are different layers, so they compose cleanly once the boundary is drawn. Detection of
which system is present is a separate concern: see
`${CLAUDE_PLUGIN_ROOT}/shared/detection-signatures.md`.

## The coordination model

A coordinated system owns a **bounded segment or concern** of the workflow — for an SDD system,
usually the spec/plan/decompose front-end; for a tracker, the work state. The orchestrator stays
the driver and coordinates that segment through a **two-way handoff**, the same shape for every
system:

1. **Activate (hand-in).** At the boundary the system owns, the orchestrator composes a
   **contextual prompt** from what it already holds — the goal, the constraints, the context it
   has gathered — and activates the system's entry point so it starts cleanly without
   re-gathering:
   - *Auto-invokable* (a CLI or MCP entry point) → the orchestrator invokes it directly with the
     contextual prompt.
   - *Human-gated* (an IDE, a SaaS UI, or a workflow with an approval step) → the orchestrator
     emits the contextual prompt for the user, **pauses**, and resumes when the user confirms
     the step is done.
2. **The system runs its owned segment.** The orchestrator does **not** duplicate it — it never
   re-derives requirements an SDD owns, and never keeps a parallel status file beside a tracker.
3. **Hand-back (return).** The system signals completion; its artifacts — a spec, a plan, a task
   graph, an issue with its state — are the **contract**. The orchestrator detects completion
   (the artifact is present, a flag is set, or the user confirms) and resumes.
4. **The orchestrator resumes its owned segment** — parallel execution, integration,
   cross-boundary QA — reading the system's artifacts as its input and **writing status and
   decisions back** in the system's own conventions. The final deliverable still goes to the
   user's target path.

### Two rules that keep it clean

- **One owner per phase, one owner per concern.** Mark each orchestrator phase as either
  delegated (`→ {system}`) or orchestrator-owned, and give each concern (requirements, task
  decomposition, work state) exactly one owning system. A phase or concern a system owns is not
  re-done by an agent, and vice versa. This is what prevents the parallel-and-conflicting flow
  the coordination exists to avoid.
- **One source of truth per artifact.** The system's artifacts are **referenced**, never copied
  into `_agents_workspace/`. The orchestrator reads them in place and writes status back in
  place. Copying a spec or an issue into the workspace creates a second copy that drifts — the
  same anti-pattern the `CLAUDE.md` pointer avoids by not duplicating the file system.

Friction is minimised by the two ends of the handoff: the **contextual prompt** on hand-in means
the system does not re-ask what the orchestrator already knows, and the
**artifact-as-contract** on hand-back means the orchestrator does not re-derive what the system
already settled.
