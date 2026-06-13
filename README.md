# agentic-harness

A [Claude Code](https://claude.com/claude-code) plugin that stands up, assesses, and maintains an **agentic harness** inside an existing repository — the project-local agents, skills, and orchestrator that make a repo work well with Claude Code.

This plugin does not do your domain work. It builds and maintains the agents and skills that do.

## Installation

```bash
# 1. Add the marketplace
claude plugin marketplace add MrBogomips/agentic-harness

# 2. Install the plugin
claude plugin install agentic-harness@mrbogomips-harness
```

Or, inside a Claude Code session:

```
/plugin marketplace add MrBogomips/agentic-harness
/plugin install agentic-harness@mrbogomips-harness
```

## The four skills

- **`harness-setup`** — the writer. Analyzes the project, designs an agent team and the skills they use, generates them into `.claude/`, builds an orchestrator, and registers a pointer in `CLAUDE.md` that makes the orchestrator the repo's entry point — a hard gate routing every prompt through it. Also extends an existing harness, applies a review context, and records every change.
- **`harness-review`** — read-only. Inventories the harness, detects drift, and assesses how effectively the skills and agents are actually used (from project memory, the `CLAUDE.md` pointer, and the `.claude/` inventory), then produces a prioritized *review context* that `harness-setup` can act on.
- **`spec-advisor`** — detects whether a software project lacks a spec-driven development system and, if so, advises the best-fit option (GitHub Spec Kit, OpenSpec, BMAD-METHOD, Agent OS, Taskmaster, AWS Kiro, ADR tooling) and delegates setup to that system's own installer. Offline-first; scans first and stays out if a system is already present; never authors specs itself.
- **`tracker-advisor`** — detects whether a software project lacks an issue tracker suited to agentic work and, if so, advises the best-fit option (Beads, Backlog.md, git-bug, git-issues, Beans, or GitHub Issues / Linear / Jira via their official access paths) and delegates setup to that system's own installer. Same posture as `spec-advisor`: offline-first, scans first and stays out, never authors issues.

## How they fit together

The harness loop: **review → setup → review again.** `harness-review` reads and prioritizes; `harness-setup` writes and records. The advisors are offered alongside the loop when a software project lacks the matching process layer — a spec system or a tracker — and they always delegate installation to the chosen system's own tooling rather than reimplementing it.

## Coordination, not duplication

When a project **already has** a spec system or an issue tracker, `harness-setup` makes the generated orchestrator coordinate with it rather than run beside it: the orchestrator activates the spec workflow with a contextual prompt and resumes on a clean hand-back, and it pulls ready work from the tracker at intake and writes status back at integrate — one owner per phase and per concern, no duplicated artifacts.

The detection signatures, the coordination protocol, and the per-system coordination maps are shared knowledge under [`shared/`](./shared/): [`detection-signatures.md`](./shared/detection-signatures.md), [`coordination-protocol.md`](./shared/coordination-protocol.md), [`sdd-coordination.md`](./shared/sdd-coordination.md), [`tracker-coordination.md`](./shared/tracker-coordination.md), [`tracker-sync-protocol.md`](./shared/tracker-sync-protocol.md).

## Dual-tracker sync

When a project runs **both** a repo-native tracker and a human-oriented one (Jira, Linear, GitHub Issues), `harness-setup` also offers to generate a **dual-tracker sync**: a project-local `tracker-sync` skill and agent that keep the SaaS tracker as a projection of the repo-native source of truth — continuous one-way push, one-time intake of human-created issues, and remote state changes treated as proposals rather than overwritten. Sync state lives in `.tracker-sync/` at the repo root; scheduled headless runs are read-and-report only. The model is in [`shared/tracker-sync-protocol.md`](./shared/tracker-sync-protocol.md); `harness-review` reads the sync state as part of its drift assessment.

## Execution modes

`harness-setup` defaults to an **agent team** and falls back to **subagents** when the experimental team tools are unavailable. See [`shared/execution-modes.md`](./shared/execution-modes.md).

## Skills, not commands

Invoke a skill directly (`/agentic-harness:harness-setup`) or let Claude trigger it from context. This plugin ships no slash commands — Claude Code merged commands into skills.

## Development

After any change, run the structural validation suite (requires `jq`):

```bash
bash tests/run-structural-tests.sh
```

Before a release or marketplace submission, also run the same check the review pipeline runs:

```bash
claude plugin validate . --strict
```

## License

MIT — see [LICENSE](./LICENSE).
