# agentic-harness

A [Claude Code](https://claude.com/claude-code) plugin that stands up, assesses, and maintains an **agentic harness** inside an existing repository — the project-local agents, skills, and orchestrator that make a repo work well with Claude Code.

This plugin does not do your domain work. It builds and maintains the agents and skills that do.

## Why use it

Instead of restarting from ad-hoc prompts every session, agentic-harness builds and maintains a project-specific team that Claude Code routes through automatically:

- **Tailored, not generic templates** — the agents and skills mirror your repo's stack, domain, and task types, not a one-size-fits-all scaffold.
- **A single entry point** — the orchestrator is registered in `CLAUDE.md` as a hard gate, so every prompt goes through the right flow instead of bypassing the harness.
- **Coordinates, doesn't duplicate** — when the project already has a spec-driven system or an issue tracker, the orchestrator coordinates with it (activates the spec and resumes on hand-back, pulls ready work and writes status back) rather than reimplementing it.
- **No lock-in** — for spec systems and trackers it advises the best fit and delegates installation to that tool's own installer; it never reinvents them.
- **Maintainable and traceable** — every change to the harness is approved before anything is written and recorded in a change-history, so its evolution stays visible and regressions stay catchable.
- **Learns from how you actually work** — `harness-review` reads the repo's recurring activities and working patterns (from project memory and the change-history) and periodically proposes improvements and optimizations to the harness, which `harness-setup` then applies.
- **A built-in improvement loop** — `harness-feedback` turns each run into structured, privacy-safe feedback so the tool itself gets better over time.

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

## The five skills

- **`harness-setup`** — the writer. Analyzes the project, designs an agent team and the skills they use, generates them into `.claude/`, builds an orchestrator, and registers a pointer in `CLAUDE.md` that makes the orchestrator the repo's entry point — a hard gate routing every prompt through it. Also extends an existing harness, applies a review context, and records every change.
- **`harness-review`** — read-only. Inventories the harness, detects drift, and assesses how effectively the skills and agents are actually used — reading the repo's **recurring activities and way of working** from project memory, the `CLAUDE.md` pointer and change-history, and the `.claude/` inventory. From that it produces a prioritized *review context* of **periodic improvements and optimizations** that `harness-setup` can act on.
- **`harness-feedback`** — closes the loop to the tool. Runs a kaizen retrospective on a harness run, drafts feedback in a standard format, redacts project-identifying details, and — only with explicit consent — files a GitHub issue on this upstream repo so the tool itself improves. Offered at the end of a `harness-setup` or `harness-review` run, or invoked on its own (`/feedback`) in a postmortem loop.
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

## Feedback loop (kaizen)

Each run is a chance to improve the tool, not just the project. `harness-feedback` turns a run into structured, privacy-safe feedback and files it as a GitHub issue here on the upstream repo:

- **One standard format** — defined once in [`shared/feedback-format.md`](./shared/feedback-format.md): eight mandatory sections (Summary, Type, What was done, Choices made, Expected outcome, What happened / friction, Suggested improvement, Environment) plus optional context. The [issue template](./.github/ISSUE_TEMPLATE/feedback.md) and the CI check both mirror this one file.
- **Redaction by default** — the harness runs in a private project but feedback lands on a public repo, so project-identifying details (repo/org names, paths, proprietary terms, secrets) are stripped before anything is shown for approval.
- **Explicit consent** — the exact issue body is shown and approved before `gh issue create` (with a prefilled-URL fallback when `gh` isn't available). Nothing is filed silently.
- **Automatic validation** — a GitHub Actions check ([`feedback-check.yml`](./.github/workflows/feedback-check.yml)) verifies every feedback issue carries the mandatory sections and auto-comments a checklist (labelling `needs-info`) when something is missing, clearing it once the issue is complete.

`tests/validate-feedback.sh` keeps the format doc, the issue template, and the CI check in sync.

## Skills, and one command

Invoke a skill directly (`/agentic-harness:harness-setup`) or let Claude trigger it from context — that is how the harness skills are meant to run, since Claude Code merged commands into skills. The one deliberate command this plugin ships is **`/feedback`**: a discoverable entry point for the kaizen feedback loop, which simply runs the `harness-feedback` skill. (It is named `/feedback`, not `/harness-feedback`, so it does not collide with the skill of that name.)

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
