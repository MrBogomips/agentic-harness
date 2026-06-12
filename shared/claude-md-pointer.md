# The CLAUDE.md pointer

A target project's `CLAUDE.md` is loaded into context at the start of every session. That
makes it the right place to record that a harness exists and when it should fire — and the
wrong place for anything the file system already holds.

## Register a minimal pointer

After a harness is built or changed, write (or update) one short section in the target
project's `CLAUDE.md`. It carries three things — plus, when the project has an installed
process layer (an SDD system, an issue tracker), one line per layer recording how the
orchestrator coordinates with it:

1. The harness's **goal**, in one line.
2. The **entry-point directive** — a hard gate making the orchestrator skill the single entry
   point for the repo: every prompt is routed through it before any response.
3. A **change-history** table.
4. *(only when an SDD system is present)* a **spec-process** line — which system, and the segment
   the orchestrator hands to it.
5. *(only when an issue tracker is present)* an **issue-tracking** line — which tracker, and how
   the orchestrator pulls ready work and writes status back.

This is enough for a fresh session: the entry-point directive gates every prompt to the
orchestrator, and the orchestrator triages and handles the rest from the files under `.claude/`.
The directive is the lever that makes activation reliable — `CLAUDE.md` is the highest-priority
instruction layer, so it does not depend on the skill description triggering on its own.

### Template

````markdown
## Harness: {domain}

**Goal:** {one line on what this harness produces}

**Spec process:** {system} ({version}) — orchestrator activates it for {owned segment};
hand-back via {contract}. *(omit this line entirely when no SDD system is present)*

**Issue tracking:** {tracker} ({version}) — orchestrator pulls ready work via {ready-work query};
status written back via {write-back convention}. *(omit this line entirely when no tracker is present)*

**Entry point — applies to every prompt in this repo:** You MUST invoke the
`{orchestrator-skill-name}` skill *before* responding to any request — new work, a follow-up, a
re-run, a question, or a change to a previous result. It is the single entry point; do not craft a
response outside it. The orchestrator decides what happens next: it answers trivial or
out-of-{domain} requests directly and runs the full team only when the work warrants it.

**Change history:**
| Date | Change | Target | Reason |
|------|--------|--------|--------|
| {YYYY-MM-DD} | Initial setup | All | — |
````

The entry-point directive is a hard gate, not a suggestion — there is no `CLAUDE.md`-level bypass.
The triage that used to live here ("answer simple questions directly") now lives *inside* the
orchestrator's first phase, so a trivial or off-domain prompt still routes through the orchestrator
and is answered quickly there. This keeps the orchestrator the reliable entry point without spinning
up a team for every message.

The spec-process and issue-tracking lines record the **coordination relationship**, not the
contents — the requirements, plan, and tasks stay in the SDD system's own files, and the issues
stay in the tracker's own store. The coordination protocol is in
`${CLAUDE_PLUGIN_ROOT}/shared/coordination-protocol.md`, with the per-area instances in
`${CLAUDE_PLUGIN_ROOT}/shared/sdd-coordination.md` and
`${CLAUDE_PLUGIN_ROOT}/shared/tracker-coordination.md`.

### When the repo has more than one harness

Write the hard-gate sentence **once**, as a shared routing preamble above the per-domain sections —
"Before responding to any request, invoke the orchestrator whose domain matches it; if none matches,
answer directly" — and keep each `## Harness: {domain}` section to its goal, an **Orchestrator:**
`{orchestrator-skill-name}` line (so the preamble can resolve domain → orchestrator), its
spec-process and issue-tracking lines, and change history. Do not repeat "invoke *this* orchestrator before any prompt"
in every section: N such directives contradict each other. One preamble routes by domain; each
section just names the orchestrator it routes to.

## What not to put here

Leave these out of `CLAUDE.md`:

- The agent list or the skill list — they live in `.claude/agents/` and `.claude/skills/`,
  and the orchestrator already knows them. Copying them here creates a second source of
  truth that drifts.
- The directory structure — readable straight from the file system.
- Detailed execution rules — they belong in the skills and the orchestrator.
- The spec contents — the spec-process line names the system and the coordinated segment only; the
  requirements/plan/tasks live in the SDD system's own files, the single source of truth.
- The issue contents — the issue-tracking line names the tracker and the touchpoints only; the
  issues live in the tracker's own store, the single source of truth for work state.

The pointer is a signpost, not a manifest. Keep it small enough that it stays correct.

## The change-history table

Every write to the harness appends a row. The columns are fixed:

| Date | Change | Target | Reason |
|------|--------|--------|--------|
| 2026-04-05 | Initial setup | All | — |
| 2026-04-07 | Added QA agent | `agents/qa.md` | deliverable-quality gaps reported |
| 2026-04-10 | Added tone guidance | `skills/content-writer` | output read as too stiff |

The table earns its place: it shows how the harness has evolved and why, which makes
regressions visible and gives the next reviewer a starting point. Recording history is a
required step of every harness write — not an optional courtesy.

On periodic review this table can be pruned, preserving valuable information and keeping it readable.
