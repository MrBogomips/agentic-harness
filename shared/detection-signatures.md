# Detection signatures

The scan-first knowledge behind flow Step 1 of `spec-advisor` and `tracker-advisor` (and behind
`harness-setup`'s process-layers gate). This is a curated **reference of facts**, not a set of
recommendations: it tells you how to recognise a spec system, an ADR registry, or an issue
tracker that is already present, so the skill can report it and stay out. A generic search
cannot reliably re-derive these signatures each run — the on-disk layouts drift in load-bearing
ways (BMAD changed its directories between v4 and v6) and several systems share filenames — so
they live here as knowledge.

## How to scan

Look for the signature paths below at the repository root and one or two levels in. One
signature is **not a path**: git-bug stores issues as git objects under the `refs/bugs/`
namespace, so check it with `git for-each-ref refs/bugs` (read-only) — a filesystem scan will
silently miss it. A hit means a system of that area **already exists**. When you find one:

- Report **what** is present and **where** (the matched path or ref), then **stop** for that
  area.
- Do not push a second system on top of one that is already in use. The skills are advisory and
  detection-first: an existing process is the user's decision, and stacking a second system on
  top of it creates exactly the duplication the skills are built to avoid.

This is a read-only report — the scan itself writes nothing. Each advisor scans its own area's
table; `harness-setup` scans both.

## Spec systems and ADR registries — path → system table

| Signature path(s) | System | Notes |
|---|---|---|
| `.specify/`, `specs/<NNN>/{spec,plan,tasks}.md` | GitHub Spec Kit | `specs/NNN-feature/` numbered dirs each holding `spec.md` + `plan.md` + `tasks.md`; `.specify/` is the tool's own config. |
| `openspec/` containing `changes/`, `specs/`, `config.yaml` | OpenSpec | Change-proposal layout — `changes/` holds in-flight proposals, `specs/` the settled capability specs. |
| `_bmad/` + `_bmad-output/` | BMAD-METHOD **v6** | New layout. Report the version — the installer and the flow differ from v4. |
| `.bmad-core/` + `docs/{prd,architecture,stories}/` | BMAD-METHOD **v4** | Legacy layout. The `docs/` artifacts (PRD, architecture, sharded stories) are the give-away. |
| `agent-os/` (v2) or `.agent-os/` (v1); plus `standards/`, `specs/` | Agent OS | `standards/` (governance) alongside light `specs/`. The dotted `.agent-os/` is the older v1 location. |
| `.taskmaster/` containing `docs/prd.txt`, `tasks/tasks.json` | Taskmaster | Task-decomposition tool; often **pairs** with a separate spec system rather than replacing one. |
| `.spec-workflow/` containing `specs/`, `steering/` | spec-workflow-mcp | MCP-surfaced workflow with an approval dashboard; `steering/` holds the project's steering docs. |
| `.kiro/specs/<feature>/{requirements,design,tasks}.md`, `.kiro/steering/` | AWS Kiro (IDE) | EARS-style `requirements.md`. Kiro is an **IDE**, not a repo install — see the Kiro caveat in `spec-systems.md`. |
| `docs/adr/`, `doc/adr/`, `.adr-dir`, `.log4brains.yml` | ADR tooling | A *decision-record* registry, not a full spec process. `.log4brains.yml` ⇒ log4brains specifically; `.adr-dir` / `docs/adr/` ⇒ adr-tools-style. |

## Issue trackers — path → system table

| Signature path(s) | Tracker | Notes |
|---|---|---|
| `.beads/` (holds an embedded Dolt db and/or `issues.jsonl`) | Beads (`bd`) | Graph-based, git-synced issue db built for coding agents. |
| `backlog/` or `.backlog/` containing `config.yml` | Backlog.md | Markdown task manager. A bare `backlog/` directory **without** the config is ambiguous — see rule 4. |
| `.issues/` with YAML-frontmatter markdown files | git-issues | Minimal single-binary tracker; may also leave a generated `.agent.md`. |
| `.beans/` with `.beans.yml` | Beans | Flat-file markdown tracker with a GraphQL query CLI. |
| `refs/bugs/` ref namespace (`git for-each-ref refs/bugs`) | git-bug | Issues live as **git objects**, not files — the filesystem shows nothing. |
| `.github/ISSUE_TEMPLATE/` | GitHub Issues (weak signal) | Usage signal only — see rule 5; never conclude on it silently. |
| `.taskmaster/` | Taskmaster | **Spec-derived** task decomposition, not a general tracker — see rule 6. |

## Human-tracker usage signals

A human-oriented SaaS tracker (Jira, Linear, GitHub Issues) rarely leaves a config file in
the repo, so its presence is read from **usage signals** rather than signature paths. These
feed `harness-setup`'s dual-tracker sync sub-step (offered only when an agentic tracker
*and* a human tracker are both present or declared). Every one of them is a signal in the
rule-5 sense — **report what was found and ask whether the tracker is actively used; never
conclude silently**:

| Signal | Points to | How to check |
|---|---|---|
| Jira issue keys in recent commit messages (`PROJ-123`-style) | Jira | `git log --oneline -100 \| grep -E '[A-Z][A-Z0-9]+-[0-9]+'` |
| `linear.app` links in the repo (README, docs, issue/PR templates) | Linear | `grep -rE 'linear\.app' --include='*.md' .` |
| A configured Atlassian or Linear MCP server in the local/session config | Jira / Linear | inspect the MCP configuration |
| Active `gh` auth plus `.github/ISSUE_TEMPLATE/` | GitHub Issues | `gh auth status`; stays **rule-5 weak** — templates alone prove nothing |

A declared tracker counts too: when the user says the team works in Jira or Linear, that is
presence — record it and confirm the access path, do not demand an on-disk artifact.

## Disambiguation rules

Six cases need a rule because the raw signal is ambiguous.

### 1. The shared `requirements.md + design.md + tasks.md` triple — resolve by parent directory

More than one system writes a `requirements.md` + `design.md` + `tasks.md` triple (AWS Kiro under
`.kiro/specs/<feature>/`, spec-workflow-mcp under `.spec-workflow/specs/<feature>/`, and others).
The filenames alone do **not** identify the system. Resolve by the **parent directory**, not the
filenames:

- under `.kiro/` ⇒ AWS Kiro,
- under `.spec-workflow/` ⇒ spec-workflow-mcp,
- under `specs/NNN-*/` with a sibling `.specify/` ⇒ Spec Kit.

If the triple sits under a parent that matches none of the known roots, the result is genuinely
ambiguous: report exactly what was found and where, and ask the user which system it is rather
than guessing.

### 2. BMAD version — `_bmad/` is v6, `.bmad-core/` is v4

BMAD-METHOD changed its on-disk layout between major versions. `_bmad/` (with `_bmad-output/`)
is the **v6** layout; `.bmad-core/` (with the `docs/{prd,architecture,stories}/` artifacts) is
the **v4** layout. Always report the detected version, because the installer command and the
workflow differ between them — a user on v4 and a user on v6 need different guidance.

### 3. ADR signals mean a decision-record registry, not a spec system

`docs/adr/`, `doc/adr/`, `.adr-dir`, or `.log4brains.yml` indicate an **Architecture Decision
Record** registry — lightweight decision logs, not a full spec-driven workflow. Report it as ADR
tooling and distinguish the tool: `.log4brains.yml` ⇒ log4brains; a plain `docs/adr/` with an
`.adr-dir` pointer ⇒ adr-tools-style. A project can hold ADRs *and* still lack a spec system — if
only ADR signals are present, say so plainly, since the user may legitimately want to add a spec
process alongside their existing decision records (offer it; do not assume it).

### 4. A bare `backlog/` directory is not Backlog.md

`backlog/` is an ordinary word that projects use for their own notes. Only the directory
**containing Backlog.md's `config.yml`** identifies the tool. A bare `backlog/` without the
config is genuinely ambiguous: report exactly what was found and ask, rather than concluding a
tracker is present.

### 5. `.github/ISSUE_TEMPLATE/` is a weak signal — report and ask

Issue templates show that GitHub Issues *has been configured at some point*, not that it is the
project's active tracker — many repos carry vestigial templates. Report "GitHub Issues appears
to be in use" and **ask** whether it is the active tracker. If yes, a tracker is present (it is
agent-reachable via `gh`) — stay out. If no, continue as if no tracker were found. Never treat
the templates alone as a silent stay-out, and never ignore them silently either.

### 6. Taskmaster appears in both tables — it is spec-derived, not a general tracker

`.taskmaster/` decomposes and tracks tasks **derived from a spec or PRD**; it pairs with a spec
system rather than serving general issue intake. `spec-advisor` treats it as an SDD pairing
(its own table row above). `tracker-advisor` reports it — "spec-derived task tracking is
covered by Taskmaster" — and stays out unless the user explicitly asks for a general issue
tracker alongside it. When both Taskmaster and a general tracker exist, work state needs one
owner per item — see `${CLAUDE_PLUGIN_ROOT}/shared/tracker-coordination.md`.
