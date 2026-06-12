# Usage assessment

How to judge whether a harness is actually *used*, not just whether it *exists*. This reads a
fixed, deterministic signal set and classifies each skill, agent, and tool. It changes
nothing — every output is a finding for `harness-setup`, never an edit.

## Why a fixed signal set

Usage is inferred, not measured directly — there is no usage counter. So ground every
judgment in a concrete signal rather than a guess. Four signals, all read-only. Read each,
state what it shows, and make the call only from evidence one of them supports. When the
signals are thin, say so and lower your confidence rather than inventing certainty.

## Signal 1: project auto-memory

Location: `~/.claude/projects/<project-hash>/memory/`. The `<project-hash>` is the project's
absolute path with the separators turned into dashes — e.g. a project at
`/Users/me/work/app` becomes a directory like `-Users-me-work-app`. Find the one whose slug
matches the project you are reviewing.

Read `MEMORY.md` (the index) and the memory files it points to. This is where the project has
recorded how work actually happens. What to look for:

- Does the memory mention the orchestrator skill, the agents, or the harness at all? Silence
  is itself a signal — a harness the project never records using is likely unused.
- Does it describe work being done **by hand** in the harness's domain? That points to the
  orchestrator being bypassed.
- Does it record friction ("the agent kept doing X")? That points to a quality or trigger
  problem to flag.

## Signal 2: the CLAUDE.md pointer and change history

Read the harness section of `CLAUDE.md`. The pointer's entry-point directive is the hard gate
routing every prompt to the orchestrator; compare what *should* route against how the project
actually describes its work (Signal 1) — a directive softer than a hard gate, or work that
happens around it, is itself a finding. The change-history table tells you the evolution:

- A pointer that names an orchestrator the files no longer contain → drift.
- A long history that stops abruptly → the harness may have been abandoned.
- History concentrated on one agent or skill → that area has been unstable; worth a look.

## Signal 3: the `.claude/` inventory

List `.claude/agents/` and `.claude/skills/`, and read the orchestrator's composition. This
is the ground truth of what the harness offers. Cross-check it against the other signals:
something in the inventory that no signal ever mentions is a candidate for "unused"; something
the memory or pointer references that is missing from the inventory is drift.

## Signal 4: the tools registry

If the orchestrator has a `tools.md` registry (from the tool-discovery step), read it: the
roles, the preferred tool and alternative per role, and the `Last reviewed` dates. What to
look for:

- A registered tool no agent or skill references by role → unused.
- A `Last reviewed` date that is far in the past → due for re-evaluation.
- A role whose preferred tool the project's memory shows failing, so the alternative is what
  runs in practice → flag the preferred tool as a candidate to swap.

## Classifying from the signals

Combine the signals and label each skill, agent, and tool:

| Class | What the signals show |
|-------|------------------------|
| **Used** | the inventory has it, and memory or history shows it being invoked or changed |
| **Unused** | it exists in the inventory, but no other signal ever references it |
| **Bypassed** | the work in its domain happens (memory shows it), but around the harness rather than through the orchestrator |
| **Drifted** | the pointer, history, or orchestrator names it, but the files disagree (missing, moved, or out of sync) |

A label is only as good as its evidence. For each, name the signal that supports it. "Unused
— not referenced in memory, history, or the orchestrator" is a finding; "probably unused" with
nothing behind it is not.

## Staying read-only

This assessment writes nothing — not the files, not `CLAUDE.md`, not memory. When the right
fix is obvious (retire an unused agent, swap a superseded tool, widen a trigger that memory
shows missing), record it as a prioritized recommendation in the review context and hand it to
`harness-setup`. The separation is the point: a reader that never writes can be trusted, and
its findings stay clean for the writer to act on.
