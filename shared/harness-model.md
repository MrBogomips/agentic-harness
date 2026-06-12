# The harness model

A *harness* is the project-local configuration that lets a repository work well with
agents. It has three parts, and keeping them separate is what makes a harness
maintainable.

## The three parts

| Part | Question it answers | Where it lives |
|------|---------------------|----------------|
| **Agent** | *Who* does the work | `.claude/agents/{name}.md` |
| **Skill** | *How* the work is done | `.claude/skills/{name}/SKILL.md` |
| **Orchestrator** | *When*, and *in what order*, the agents collaborate | a skill, usually `.claude/skills/{domain}-orchestrator/` |

An **agent** is an expert role: a persona, its working principles, its input/output
contract, and — in team mode — how it communicates with other agents. An agent is small.
It says who is acting and what that actor cares about, not the step-by-step procedure.

A **skill** is procedural knowledge: the workflow an agent follows, the format it
produces, the references it consults. A skill can be large. It says how a job is done,
independent of who does it.

An **orchestrator** is a skill whose subject is the team itself. Where individual skills
describe one agent's job, the orchestrator describes the collaboration: which agents take
part, what each produces, how their outputs flow together, and how failures are handled.

## Why separate who from how

The separation is not bookkeeping. It buys three concrete things:

- **Reuse.** A skill written for "how to review an API contract" is usable by any agent
  that needs it, in this project or the next. Bind the procedure to a single named agent
  and it stops being portable.
- **Independent change.** When a deliverable is weak, you revise the skill. When you need
  a new kind of reviewer, you add an agent. When the workflow order is wrong, you edit the
  orchestrator. Each fault has one obvious place to fix it.
- **Survival across sessions.** An agent defined only inline in a prompt vanishes when the
  session ends. An agent defined as a file is there next time, with its protocol intact
  and its memory.

## The file rule

Every agent is a file under `.claude/agents/`, even when it uses a built-in type
(`general-purpose`, `Explore`, `Plan`). Put the built-in type in the call that spawns the
agent; put the role, principles, and protocol in the file. A role written only into a
spawn prompt is not reusable and carries no collaboration contract — so it is not part of
the harness.

## How the parts connect

One agent uses one or more skills; a skill may be shared by several agents. The
orchestrator names the agents and points each at its skills. The pointer in the target
project's `CLAUDE.md` names only the orchestrator and its entry-point directive (the hard gate
that routes every prompt through it) — see `claude-md-pointer.md`. Nothing in the harness duplicates what the file system already
states: the agent and skill lists live in `.claude/`, not in `CLAUDE.md`.
