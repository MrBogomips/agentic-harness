# Spec systems — curated profiles

The recommend-and-delegate knowledge behind flow Steps 4 and 5. One profile per system in the
curated shortlist, then the selection decision tree, the Kiro/IDE caveat, and the online policy.

These are the facts the skill reasons over offline. Treat install commands and URLs as
load-bearing: when a system is **selected** (not before), the official-repo fetch in flow Step 5
is what confirms the current command — these values are the offline baseline and the source of
the URL to fetch.

For how a generated orchestrator coordinates with each of these systems once it is installed (the
hand-in / hand-back protocol and the per-system owned segment), see
`${CLAUDE_PLUGIN_ROOT}/shared/sdd-coordination.md` — that is `harness-setup`'s concern, not this
skill's.

## Per-system profiles

### GitHub Spec Kit
- **Official repo:** github.com/github/spec-kit
- **Install (into repo):** `uv tool install specify-cli --from git+https://github.com/github/spec-kit.git` then `specify init .`
- **On-disk artifacts:** `.specify/`, `specs/<NNN>/{spec,plan,tasks}.md`
- **Philosophy / stages:** specify → plan → tasks; an agent-agnostic, prompt-driven spec workflow.
- **Claude Code affinity:** high — designed to drive coding agents, Claude Code included.
- **Maturity:** the most widely adopted of the shortlist; active.
- **Best-fit:** a popular agent-agnostic standard; greenfield or feature-driven work.

### OpenSpec
- **Official repo:** github.com/Fission-AI/OpenSpec
- **Install (into repo):** `npm i -g @fission-ai/openspec` then `openspec init`
- **On-disk artifacts:** `openspec/` with `changes/`, `specs/`, `config.yaml`
- **Philosophy / stages:** lightweight change-proposal specs — propose a change, settle it into a capability spec.
- **Claude Code affinity:** good; CLI-driven, fits an agent loop.
- **Maturity:** newer, focused; active.
- **Best-fit:** brownfield work where a full pipeline is too heavy and change-scoped specs fit better.

### BMAD-METHOD
- **Official repo:** github.com/bmad-code-org/BMAD-METHOD
- **Install (into repo):** `npx bmad-method install`
- **On-disk artifacts:** **v6** `_bmad/` + `_bmad-output/`; **v4** `.bmad-core/` + `docs/{prd,architecture,stories}/`
- **Philosophy / stages:** a heavy agile pipeline with named agent personas (analyst, PM, architect, scrum master, dev) producing PRD → architecture → sharded stories.
- **Claude Code affinity:** high, but opinionated — it brings its own multi-agent process.
- **Maturity:** mature and feature-rich; note the v4/v6 layout split (see `${CLAUDE_PLUGIN_ROOT}/shared/detection-signatures.md`).
- **Best-fit:** teams that want a full, ceremony-rich agile workflow; greenfield-leaning.

### Agent OS
- **Official repo:** github.com/buildermethods/agent-os
- **Install (into repo):** a base install script (`base-install.sh`) followed by a per-project install.
- **On-disk artifacts:** `agent-os/` (v2) or `.agent-os/` (v1); `standards/`, `specs/`
- **Philosophy / stages:** standards governance (coding standards, best practices) plus light specs.
- **Claude Code affinity:** good; standards-as-context fits agent prompting.
- **Maturity:** active.
- **Best-fit:** an existing team that wants standards/governance with a lighter spec layer than BMAD.

### Taskmaster
- **Official repo:** github.com/eyaltoledano/claude-task-master
- **Install (into repo):** `npx -y task-master-ai` (also available as an MCP server).
- **On-disk artifacts:** `.taskmaster/` with `docs/prd.txt`, `tasks/tasks.json`
- **Philosophy / stages:** parse a PRD into a task graph, then track and expand tasks.
- **Claude Code affinity:** high — built for agent task execution; MCP option integrates directly.
- **Maturity:** active and popular.
- **Best-fit:** task decomposition and tracking. It **pairs** with a spec system rather than replacing one — recommend it *alongside* a spec tool when the need is breaking an existing spec into trackable work. For general issue/bug intake (not spec-derived tasks), the tracker shortlist is `tracker-advisor`'s concern.

### spec-workflow-mcp
- **Official repo:** github.com/Pimzino/spec-workflow-mcp
- **Install (into repo):** `claude mcp add-json …` (registered as an MCP server).
- **On-disk artifacts:** `.spec-workflow/` with `specs/`, `steering/`
- **Philosophy / stages:** a spec workflow surfaced through MCP, with an approval dashboard and steering documents.
- **Claude Code affinity:** high — it is an MCP server, so it plugs into Claude Code natively.
- **Maturity:** active.
- **Best-fit:** teams who want the spec workflow exposed as MCP tooling with an explicit approval step.

### AWS Kiro — IDE, advise only
- **Official source:** kiro.dev
- **Install:** **none into the repo.** Kiro is an IDE. Do **not** attempt a repo install — see the Kiro caveat below.
- **On-disk artifacts:** `.kiro/specs/<feature>/{requirements,design,tasks}.md`, `.kiro/steering/`
- **Philosophy / stages:** EARS-style requirements → design → tasks, authored inside the Kiro IDE.
- **Claude Code affinity:** orthogonal — it is a different editor/agent surface, not a Claude Code add-on.
- **Maturity:** AWS-backed.
- **Best-fit:** teams committed to an IDE/AWS workflow who want EARS requirements. Detect-and-advise only.

### ADR tooling
- **Official repos:** github.com/thomvaill/log4brains · github.com/npryce/adr-tools
- **Install (into repo):** log4brains — `npm i -g log4brains` then `log4brains init`; adr-tools — `adr init`.
- **On-disk artifacts:** `docs/adr/`, `.adr-dir`, `.log4brains.yml`
- **Philosophy / stages:** Architecture Decision Records — short, append-only decision logs. Not a full spec process.
- **Claude Code affinity:** neutral; plain markdown an agent can read and append.
- **Maturity:** both established.
- **Best-fit:** projects that want lightweight **decision records only**, with no full spec pipeline.

## Selection decision tree

Walk this top-down with the profile gathered in flow Step 3; the first match that fits wins, and
present 2–3 candidates with rationale rather than a single verdict.

1. **Committed to an IDE / AWS workflow, want EARS?** → AWS Kiro — **advise only** (see caveat).
2. **Want decision records only, no full spec process?** → an ADR registry (log4brains, or adr-tools).
3. **Want a popular, agent-agnostic standard?** → GitHub Spec Kit.
4. **Brownfield, want lightweight change-proposal specs?** → OpenSpec.
5. **Want a heavy agile pipeline with agent personas?** → BMAD-METHOD.
6. **Want standards governance with a light spec layer?** → Agent OS.
7. **Want the workflow surfaced as MCP with an approval dashboard?** → spec-workflow-mcp.
8. **Need task decomposition over an existing/already-chosen spec?** → Taskmaster, **paired** with the spec tool above (it complements, it does not replace).

## Kiro / IDE caveat

Kiro is an **IDE**, not a repository package. A Claude Code skill cannot install an IDE into a
repo, and pretending to would leave the project in a half-configured state. So for Kiro the skill
is **detect-and-advise only**: explain what Kiro is, point the user at the official source
(kiro.dev), and stop. Do not run an installer, do not scaffold `.kiro/` by hand. The same rule
applies to any future IDE-bound option: if setup means "install an editor," advise, do not install.

## Online policy

The default is **fully offline** — everything above is enough to scan, profile, recommend, and
name an install command without touching the network. Online access is never automatic and takes
exactly two narrow forms:

- **(a) Discovery search** — a broad "is there anything new, or a newer option than the shortlist?"
  web search. **Offer** it before finalizing a recommendation; run it **only on an explicit yes**.
  If it stalls or the environment is offline, fall back silently to the curated data above.
- **(b) Authoritative fetch** — once the user **selects** a system, fetch its current setup details
  (install command, docs) from **that system's official repository** — the URL in its profile
  above — not a broad search. This is a precise fetch from the canonical source, the lean way to
  confirm the command is current before you ask for approval to run it.

Neither form runs on its own. The offline path is complete; online is opt-in and additive.
