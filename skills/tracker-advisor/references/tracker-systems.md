# Issue trackers — curated profiles

The recommend-and-delegate knowledge behind flow Steps 4 and 5. One profile per tracker in the
curated shortlist, then the selection decision tree, the SaaS/MCP caveat, and the online policy.

These are the facts the skill reasons over offline. Treat install commands and URLs as
load-bearing: when a tracker is **selected** (not before), the official-repo fetch in flow Step 5
is what confirms the current command — these values are the offline baseline and the source of
the URL to fetch.

For how a generated orchestrator coordinates with each of these trackers once it is installed
(the phase-0 ready-work pull, the status write-back, and the per-tracker command map), see
`${CLAUDE_PLUGIN_ROOT}/shared/tracker-coordination.md` — that is `harness-setup`'s concern, not
this skill's.

## Per-system profiles

### Beads (`bd`)
- **Official repo:** github.com/steveyegge/beads
- **Install (into repo):** `brew install beads` or `npm install -g @beads/bd`, then `bd` init in the repo. `bd setup claude` wires the Claude Code integration.
- **On-disk artifacts:** `.beads/` (embedded Dolt database plus a git-synced `issues.jsonl` export)
- **Philosophy:** a graph-based, git-backed issue database built as working memory for coding agents — dependency types (blocks, parent/child, related, discovered-from), `bd ready --json` for unblocked work, hash-based IDs that survive concurrent branches.
- **Agent affinity:** highest of the shortlist — ready-work queries, atomic claim, multi-agent-safe IDs, JSON everywhere.
- **Maturity:** v1.x, actively maintained; license GPL-3.0.
- **Best-fit:** multi-agent concurrency, dependency-heavy work, high-volume task creation.

### Backlog.md
- **Official repo:** github.com/MrLesk/Backlog.md
- **Install (into repo):** `npm i -g backlog.md` (or `bun add -g backlog.md`, `brew install backlog-md`), then `backlog init`
- **On-disk artifacts:** `backlog/` (or `.backlog/`) containing `config.yml` and markdown task files
- **Philosophy:** markdown-native tasks in git — one diffable file per task — with a CLI (`backlog task create/edit/list`), a terminal/web kanban board, and a bundled MCP server (`backlog mcp start`).
- **Agent affinity:** high — first-class MCP support and a clean CLI; tasks stay human-readable.
- **Maturity:** actively maintained, frequent releases; license MIT.
- **Best-fit:** solo devs or small teams who want a human-browsable kanban over plain markdown, with agents working the same files.

### git-bug
- **Official repo:** github.com/git-bug/git-bug
- **Install (into repo):** install the binary (releases or package manager); issues then live in the repo itself — no init scaffolding in the working tree.
- **On-disk artifacts:** none in the working tree — issues are **git objects** under the `refs/bugs/` namespace (detect with `git for-each-ref refs/bugs`).
- **Philosophy:** distributed, offline-first bug tracking embedded in git, with CLI/TUI/web interfaces and bridges to GitHub and GitLab.
- **Agent affinity:** medium — solid CLI (`git bug add`, `git bug ls`), but no ready-work/dependency model and the object storage is less directly inspectable than files.
- **Maturity:** long-lived project, maintained at a slower cadence; license GPL-3.0.
- **Best-fit:** pure-git purists who want issues to travel with clones and bridge to a forge.

### git-issues — early-stage
- **Official repo:** github.com/git-issues/git-issues
- **Install (into repo):** single Go binary; issues live as YAML-frontmatter markdown in `.issues/`
- **Philosophy:** the minimal agent loop — `issues next` → `issues claim` → `issues done` — plus a TUI board for humans and a generated `.agent.md` context file.
- **Agent affinity:** high in design (the next/claim/done verbs are agent-shaped), small in surface.
- **Maturity:** **young — no formal releases yet.** Confirm current state at the official repo before recommending; present it as an early-stage option, not an established one. License LGPL-2.1.
- **Best-fit:** minimal-footprint projects that want exactly the claim/done loop and nothing else.

### Beans — early-stage
- **Official repo:** github.com/hmans/beans
- **Install (into repo):** `brew install hmans/beans/beans` or `go install github.com/hmans/beans@latest`, then `beans init`
- **On-disk artifacts:** `.beans/` with `.beans.yml`
- **Philosophy:** flat-file markdown issues with a built-in GraphQL query engine, so agents pull exactly the fields they need; archived issues double as project memory.
- **Agent affinity:** high in design — token-efficient structured queries over plain files.
- **Maturity:** **v0.x, under heavy development — APIs may change.** Present as early-stage. License Apache-2.0.
- **Best-fit:** small projects that value token-efficient structured queries over ecosystem maturity.

### GitHub Issues — SaaS, advise only
- **Official source:** github.com (CLI: cli.github.com)
- **Install:** **none into the repo.** If the project is hosted on GitHub, the tracker already exists; agent access is `gh issue list --json …`, `gh issue create`, `gh issue close`, `gh issue comment` (authenticated `gh`).
- **Philosophy:** the forge's native tracker — deep PR/commit context, team-visible, zero extra tooling.
- **Agent affinity:** good via `gh` JSON output; no dependency graph or ready-work model.
- **Best-fit:** GitHub-hosted teams who want one tracker humans and agents share, with no new tool.

### Linear — SaaS via MCP, advise only
- **Official source:** linear.app (MCP server: mcp.linear.app, vendor-provided)
- **Install:** **none into the repo.** Agent access is the official MCP server: `claude mcp add --transport http linear-server https://mcp.linear.app/mcp`, then authenticate via `/mcp`.
- **Philosophy:** a modern human-oriented tracker; the MCP server exposes issue search/create/update to agents.
- **Agent affinity:** good when the MCP server is configured; cloud-dependent, not git-managed.
- **Best-fit:** teams already running on Linear. A repo-native tracker can still be added for agent-side work — keeping the two in sync is a planned future capability of this plugin, not this skill.

### Jira — SaaS via MCP, advise only
- **Official source:** atlassian.com (MCP: the Atlassian remote MCP server at mcp.atlassian.com, vendor-provided)
- **Install:** **none into the repo.** Agent access is the official Atlassian MCP server (added via `mcp-remote` to `https://mcp.atlassian.com/v1/sse`), OAuth-scoped to the user's own permissions.
- **Philosophy:** the enterprise standard — rich custom workflows, heavyweight for small teams.
- **Agent affinity:** workable via MCP; workflows are per-project custom, so agents must read them, not assume them.
- **Best-fit:** organizations already committed to Jira. As with Linear, dual-tracker sync with a repo-native tracker is a planned future capability of this plugin.

### Taskmaster — boundary note, not a profile
Taskmaster (`.taskmaster/`) is **spec-derived task decomposition** — it parses a PRD into a task
graph and tracks those tasks. It belongs to the spec process and sits in `spec-advisor`'s
shortlist, not this one. If the need is "break the spec into trackable work," route to
`spec-advisor`; if Taskmaster is already present, see disambiguation rule 6 in
`${CLAUDE_PLUGIN_ROOT}/shared/detection-signatures.md`.

## Selection decision tree

Walk this top-down with the profile gathered in flow Step 3; the first match that fits wins, and
present 2–3 candidates with rationale rather than a single verdict.

1. **Already committed to GitHub Issues / Linear / Jira as the team's tracker?** → that SaaS
   profile — **advise only** (see caveat); for Linear/Jira mention the planned dual-tracker sync
   path.
2. **Multiple agents working concurrently, or dependency-graph needs?** → Beads.
3. **Want a human-browsable kanban over plain markdown files?** → Backlog.md.
4. **Want issues as pure git objects that travel with clones, with forge bridges?** → git-bug.
5. **Want the most minimal claim/done loop, comfortable with early-stage tools?** → git-issues
   or Beans (flag both as early-stage).
6. **Only need spec-derived task decomposition?** → that is Taskmaster — route to
   `spec-advisor`.

## SaaS / MCP caveat

GitHub Issues, Linear, and Jira are **services**, not repository packages. A Claude Code skill
cannot install a SaaS into a repo, and scaffolding fake local state for one would be worse than
doing nothing. So for these the skill is **detect-and-advise only**: explain the option, point at
the official access path (`gh` for GitHub; the vendor MCP servers for Linear and Jira), and stop.
Configuring an MCP server is the user's call under their own credentials — name the official
command, do not run authentication flows for them. The same rule applies to any future SaaS
option: if setup means "sign into a service," advise, do not install.

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
  confirm the command is current before you ask for approval to run it. For the early-stage
  entries (git-issues, Beans) this fetch is **strongly recommended**, since young tools change
  fast.

Neither form runs on its own. The offline path is complete; online is opt-in and additive.
