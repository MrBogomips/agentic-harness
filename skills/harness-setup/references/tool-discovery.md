# Tool discovery

How the tool-discovery step works: how to brief the search subagent, how candidates are
accepted, and how accepted tools are registered so agents and skills can use them without
hard-coding a tool name. Supplements Step 1b.

## When it runs

Step 0 of `harness-setup` always offers tool research as part of the plan; this step runs
when the user accepts. It can also be triggered on its own ("find tools / MCPs / plugins for
this project"), and runs equally well during an initial build or standalone against an
existing harness. Offering is automatic; running is not — and no individual tool is adopted
without a separate explicit yes. This skill ships **no catalog of recommendations** — every
candidate comes from a live search and the local configuration.

## Step 1: Brief the search subagent

Dispatch a search-optimized subagent and give it a tight context so its search is grounded in
this project, not generic. Use the `general-purpose` type (it has web search and fetch); run
it in the background while you continue. The brief:

```text
You are searching for external tools — MCP servers and Claude Code plugins — that would help
this project's harness. Project context:
- Domain: {from Step 1}
- Stack / languages / frameworks: {from Step 1}
- Core task types: {creation / validation / analysis / ...}
- Pain points or repeated manual work the user mentioned: {if any}

For each candidate, return: the ROLE it fills (e.g. "knowledge base", "language server",
"issue tracker CLI"), the concrete tool, what it does, its maturity/maintenance signal, and
its main trade-off or cost. Do not rank or recommend — just surface grounded candidates with
evidence. Prefer well-maintained, widely-used tools; flag anything experimental.
```

The categories are illustrative, not prescriptive — a document-heavy project might benefit
from a markup-conversion MCP, a code project from a language-server tool, a project tracked
in an external issue tracker from that tracker's CLI or MCP. What actually fits is whatever the
search and the project context turn up.

## Step 2: Check the local configuration

Before proposing anything, inspect what is already available in the local and session
configuration — connected MCP servers, installed plugins, CLIs on the path. The point is
twofold: don't propose a tool the project already has, and surface useful tools already
present that the harness isn't using yet. Fold both into the candidate list.

## Step 3: Get explicit acceptance

Present the candidates to the user, each with its role, what it does, and its trade-off. The
user **accepts or rejects each one individually**. Adopt only the accepted ones. Do not
batch-accept, and do not adopt a tool on the user's behalf because it "seems useful" — an
external tool is a dependency and a trust decision, and that decision is the user's.

For an accepted tool that needs configuration (an MCP server, a plugin), set it up only as
far as the user authorizes, and note any credentials or installation the user must complete
themselves.

## Step 4: Register accepted tools

Registration and any install or uninstall is a write, so it happens only after the change
manifest is approved (`harness-setup` Step 2b). For a standalone tool run, present a
tools-only manifest and get approval before writing.

Record accepted tools **by role** in the registry under the orchestrator:
`.claude/skills/{domain}-orchestrator/references/tools.md`. One registry per harness; the
orchestrator owns it. The schema:

```markdown
# Tools registry

Agents and skills reference a tool by its **role**, never by a hard tool name. When the
preferred tool is unavailable, fall back to the alternative. Reviewed on the dates below.

| Role | Preferred tool | Alternative (if unavailable) | Status | Last reviewed |
|------|----------------|------------------------------|--------|---------------|
| knowledge-base | {accepted MCP} | built-in file search | active | {YYYY-MM-DD} |
| language-server | {accepted tool} | manual code reading | active | {YYYY-MM-DD} |
| issue-tracker | {accepted CLI} | none — note the gap | active | {YYYY-MM-DD} |
```

Every role needs an **alternative**, even if the alternative is "none, and here is what the
agent does without it." The alternative is what keeps the harness working when a tool is
absent or unreachable — the same graceful-degradation idea the marketplace applies to its own
optional connectors.

## Step 5: Reference tools by role

In an agent definition or a skill, name the **role**, not the tool. For example: "retrieve
context using the `knowledge-base` tool from the orchestrator's tools registry; if it is
unavailable, use the registered alternative." This keeps the concrete tool swappable: change
the registry row and every agent and skill follows, with no edits to their files.

## Step 6: Periodic review

Registered tools are not permanent. A tool can fall out of use, stop being maintained, or be
overtaken by a better option. Re-evaluate the registry periodically — whether each tool is
still earning its place, and whether a better alternative now exists — and update the `Last
reviewed` date. Assessing tool usage is a read activity that belongs to `harness-review`;
acting on it (swapping or retiring a tool) is a write that comes back here. The cadence and
the triggers are in `references/maintenance.md`.
