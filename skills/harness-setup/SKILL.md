---
name: harness-setup
description: "Build, extend, and maintain a project's agentic harness — the agents, skills, and orchestrator under .claude/. This skill writes files. Use it to set up, scaffold, extend, rebuild, or sync a harness, to add or change an agent or skill, or to apply a review context from harness-review; on request it also discovers and registers fitting MCP/plugin tools, offers a visual stack chosen with visual-advisor, and generates a setup-check skill backed by harness-doctor. When a project runs both a repo-native tracker and a human tracker (Jira, Linear, GitHub Issues), it also generates the dual-tracker sync — use it for 'keep the trackers in sync', 'sync issues to Jira/Linear', or 'tracker sync setup'. For read-only assessment of an existing harness, use harness-review — this skill is the writer, that one is the reader. Not for authoring a single standalone skill or plugin (use plugin-dev or skill-creator), or one-shot automation recommendations (use claude-code-setup). Not for choosing a project's spec-driven development system or issue tracker — use spec-advisor or tracker-advisor. Not for checking what is installed on the machine — use harness-doctor."
model: inherit
---

# Harness setup — build and maintain the agent team

This skill builds and maintains a project-local **agentic harness**: a team of agent
definitions, the skills those agents use, an orchestrator that coordinates them, and a
pointer in the project's `CLAUDE.md`. It writes files. It does not do the project's domain
work — it builds the agents and skills that do.

Read the model first: `${CLAUDE_PLUGIN_ROOT}/shared/harness-model.md` defines the three
parts (agent = who, skill = how, orchestrator = when/order) and why they stay separate.

## This skill vs harness-review

`harness-setup` is the **writer** — every change to the harness goes through it. `harness-review`
is the **reader** — it assesses an existing harness and writes nothing. When a request is
"assess / review / audit / how well is it used," that is `harness-review`. When a request
creates or changes anything, it is this skill. After `harness-review` hands off a *review
context*, this skill is what acts on it.

## Step 0: Orient before writing

Always check the current state first, then pick the path. Do not start generating until the
plan is confirmed.

1. **Take the user's starting context, if any.** This skill accepts an optional context at
   the start — domain notes, constraints, tools already in use, or a review context from
   `harness-review`. Read it and fold it into everything below.
2. Read `.claude/agents/`, `.claude/skills/`, and the harness section of `CLAUDE.md`.
3. Branch on what you find:
   - **New build** — no harness, or empty agent/skill dirs → run Steps 1–7 in full.
   - **Extend** — a harness exists and the request adds or changes an agent or skill → run
     only the needed steps, per the extension matrix in `references/maintenance.md`.
   - **Apply a review context** — `harness-review` produced a prioritized list → work it as
     an interactive improvement pass (see `references/maintenance.md`).
   - **Sync** — the files and the `CLAUDE.md` record disagree → reconcile and record the
     correction.
4. Present the plan and confirm it before generating. Tool research and tool maintenance are
   part of a good harness, so make them part of the plan you present **every run** — don't
   wait to be asked:
   - **Always ask whether to run tool discovery** (Step 1b), on a new build or an extension.
     The question includes the **visuals sub-step** — one line on what a visual stack would do
     for this domain; the full briefing runs only if the user wants it.
   - **On an existing harness** (extend / apply-review-context / sync), **also ask whether to
     run a tool-maintenance review** of the registered `tools.md` (see
     `references/maintenance.md`).
   Record the answers. Asking is the default; a "no" is a fine answer, but a silent skip is
   not. Running happens only on a yes — see Step 1b. This confirms the approach; the concrete
   list of files and tools is approved separately at Step 2b, before anything is written.
5. **Account for the project's process layers.** A harness is the *who/how/when* of the work; a
   project may also follow *process layers* — a spec process (what to build) and an issue
   tracker (what work is ready and in what state). They are complementary to the harness, so
   check each advisor area — scan with
   `${CLAUDE_PLUGIN_ROOT}/shared/detection-signatures.md`:

   | Process area | Advisor skill | Coordination map |
   |---|---|---|
   | Spec process (SDD) | `spec-advisor` | `${CLAUDE_PLUGIN_ROOT}/shared/sdd-coordination.md` |
   | Issue tracking | `tracker-advisor` | `${CLAUDE_PLUGIN_ROOT}/shared/tracker-coordination.md` |

   The same gate applies to every area:
   - **No system, project looks like software** → offer to run the area's advisor skill, which
     advises what fits and delegates setup to the chosen system's own installer. Offering is the
     default; running is gated on a yes, and nothing is installed without the advisor's own
     per-system approval. If the user installs one, fold its coordination into the plan below.
     **If the advisor reports an installer failure, treat the area as having no system** — record
     no coordination context; the advisor leaves the retry path with the user.
   - **A system is present** (detected, or just installed) → do not re-recommend and do not
     install. Identify the system and version, look up its row in the area's coordination map,
     and record a **coordination context** — for SDD `{system, version, owned-segment,
     activation, auto-invokable, hand-back contract, write-back rule}`; for a tracker
     `{tracker, version, entry point, ready-work query, create convention, status write-back,
     auto-invokable}` — to carry into Step 2 and Step 5. This is the lightweight read
     `harness-setup` needs to bake the coordination into the orchestrator; the advisor skills
     still own recommending and installing. The protocol behind every map is
     `${CLAUDE_PLUGIN_ROOT}/shared/coordination-protocol.md`.

   - **Both an agentic tracker and a human tracker present or declared** (a repo-native
     tracker like Beads plus Jira, Linear, or GitHub Issues — the human-tracker usage signals
     are in `${CLAUDE_PLUGIN_ROOT}/shared/detection-signatures.md`) → also offer the
     **dual-tracker sync sub-step**: generate the project's `tracker-sync` skill, agent, and
     sync config per `${CLAUDE_PLUGIN_ROOT}/shared/tracker-sync-protocol.md`, using
     `references/tracker-sync-template.md`. Offer it **only** on this dual-tracker condition —
     never when one tracker or none is present. Before generating any sync artifact, run the
     **sync preflight**: validate the recorded tracker coordination context by actually calling
     both entry points — the ready-work query on the agentic side, `human-tracker` role
     resolution plus a cheap ping on the SaaS side. A failed validation stops the sub-step and
     corrects the context first; never generate against a stale context.

   Record the answer for each area either way. A future advisor adds a row to the table; the
   gate itself does not change.

## Step 1: Analyze the domain

1. Identify the domain and the core task types (creation, validation, editing, analysis).
2. Explore the codebase — tech stack, data models, key modules — so agents and skills fit
   the project rather than a generic template.
3. Check for conflicts or overlap with any existing agents and skills from Step 0.
4. Read the user's technical level from the conversation and match your wording to it.
   Explain a term like "assertion" or "schema" when the cues suggest it is unfamiliar.

## Step 1b: Discover tools — always offered, run on acceptance

Step 0 always offers tool research as part of the plan; run this step when the user accepts.
It can also be triggered on its own later, against an existing harness. Offering is the
default; running is gated on that yes — and adopting any individual candidate is gated on a
separate, explicit per-tool yes (Step 3). Those two gates are the safeguard: the user is
always asked, and nothing is installed behind their back.

This skill proposes nothing of its own — the candidates come from a live search, not a
built-in catalog:

1. Hand a **search-optimized subagent** (`general-purpose`, with web search) a tight context
   — the project's domain, stack, and task types from Step 1 — and have it find candidate
   MCP servers and plugins that fit. Also inspect the local and session configuration for
   tools already available, so you don't propose what is already there.
2. Present each candidate with the **role** it would fill, what it does, and its trade-off.
   The user **accepts or rejects each one explicitly**. Adopt only what is accepted.
3. Accepted tools become install/register rows in the Step 2b manifest; once that is
   approved, register them **by role** in the tools registry under the orchestrator — a
   `tools.md` file in `.claude/skills/{domain}-orchestrator/references/`. It is a lookup of
   role → preferred tool → alternative (for when the preferred one is unavailable) → status.
   Agents and skills reference a tool by its **role**, never by a hard tool name, so the
   harness falls back to the alternative when a tool is missing.

4. **Curated role: visuals.** As part of the same run, invoke `visual-advisor` with the Step 1
   domain profile. It briefs the user on where visuals would and would not help this domain,
   invites their own visual patterns and tools, and returns a **visual stack context** (review
   surface, generators, style source, patterns, environment, cost and share policies). Its tools
   join the candidate list under the roles `visual-review-surface` and `visual-generator`; the
   context drives the `{domain}-visuals` skill in Step 4. A "no" skips it — and Step 4 then
   generates no visuals skill. Visuals are the one role with a curated catalog; the reason is in
   `references/tool-discovery.md`.

Before the search, inventory what is already installed with plain read-only listings
(`claude plugin list`, the MCP server names in `claude mcp list` or `/mcp`, the skill
directories). After the search, pass the candidate list — plus any existing `tools.md` rows — to
`harness-doctor`, so each candidate arrives with a verified status and missing ones as pinned
install rows. The subagent's context
template, the acceptance flow, and the registry schema are in `references/tool-discovery.md`. Registered tools are reviewed periodically — see
`references/maintenance.md`.

## Step 2: Choose the execution mode and the architecture pattern

**Execution mode.** Default to **subagents**. Choose an **agent team** when two or more agents
genuinely need to exchange information mid-task *and* the experimental team tools are enabled
(`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). Keep a subagent fallback for when they are not. The team-tools caveat and the mechanical fallback
mapping are in `${CLAUDE_PLUGIN_ROOT}/shared/execution-modes.md` — read it and decide the
mode before designing the team, because the mode shapes the agent definitions and the
orchestrator.

**Architecture pattern.** Decompose the work into areas of expertise and pick a structure.
The six patterns — Pipeline, Fan-out/Fan-in, Expert Pool, Producer-Reviewer, Supervisor,
Hierarchical Delegation — with their fit and their team-mode suitability are in
`references/agent-design-patterns.md`. Composite patterns are common; the same reference
covers them.

**Split agents** along four axes — expertise, parallelism, context, reusability. The
criteria table is in `references/agent-design-patterns.md`. Prefer a few focused agents over
many thin ones; coordination cost grows with team size.

**Coordinate with the process layers.** If Step 0 recorded a coordination context, decide *with
the user* how the orchestrator and each present system compose — they must work together without
overlap and with minimal friction, not run in parallel.

- **Spec process (SDD).** Using `${CLAUDE_PLUGIN_ROOT}/shared/sdd-coordination.md`, settle: which
  phases the orchestrator **delegates** to the SDD (the spec/plan/decompose segment it owns) versus
  **owns** (typically execution, integration, and a cross-boundary QA pass); and whether activation
  is **auto-invokable** (the orchestrator calls the SDD's CLI/MCP entry point with a contextual
  prompt) or **human-gated** (it emits the prompt and pauses for the user, as with an IDE or an
  approval step).
- **Issue tracker.** Using `${CLAUDE_PLUGIN_ROOT}/shared/tracker-coordination.md`, settle: which
  phases touch the tracker (phase 0 pulls ready work or creates the issue; integrate writes status
  back); whether access is **auto-invokable** (CLI / configured MCP) or **human-gated** (a SaaS UI
  with no configured access); and the **one-status-owner rule** when Taskmaster or an SDD task
  artifact co-exists with the tracker — each item's work state has exactly one owning system.

Fold the decisions into the Step 2b manifest so they are approved before any write.

## Step 2b: Approve the change manifest — required before any write

Before creating, updating, or deleting anything — and before installing or uninstalling any
tool — present a single explicit **change manifest** and get the user's formal approval. This
is mandatory on every path: new build, extend, apply-review-context, sync. Nothing is written
to `.claude/` or `CLAUDE.md`, and no tool is installed or removed, until the user approves it.

This is not the Step 0 plan confirmation. Step 0 agrees the approach before the design exists;
the manifest is the concrete, itemized list of exactly what this run will touch, produced once
the design is settled. Writes and installs change the user's repository and environment and are
awkward to undo — one explicit sign-off on the exact list is what keeps the run from making a
change the user did not expect.

Present it as concrete items, each labelled with its action and target:

| Action | Target |
|--------|--------|
| create / update / remove | `.claude/agents/{name}.md` (one row per agent) |
| create / update / remove | `.claude/skills/{name}/` (one row per skill) |
| create / update | `.claude/skills/{domain}-orchestrator/` |
| update | `CLAUDE.md` (harness pointer + change-history row) |
| install / uninstall | `{role} -> {tool}` (only if tool discovery, visual-advisor, harness-doctor, or maintenance proposed it; one command per approval, pinned, per the install safety contract in `harness-doctor`) |
| register / unregister schedule | `{venue} — {cadence} — {mode}` (one row per scheduled run; **environment-level** — approving it changes the user's machine, not just the repo) |

List only the rows that apply. If the user amends the list — drops an agent, declines a tool,
renames a skill — revise and present it again; the approval is of the final list. Once
approved, carry out exactly what was approved in Steps 3–6 — no extra files, no extra installs.

## Step 3: Generate the agent definitions

Write every agent as a file under `.claude/agents/{name}.md` — including agents that use a
built-in type (`general-purpose`, `Explore`, `Plan`). Put the built-in type in the spawn
call; put the role, principles, and protocol in the file. The reason is in the harness
model: a role defined only inline is not reusable next session and carries no collaboration
contract.

Each agent file carries what the model cannot infer on its own: the role's purpose and
quality bar, its responsibilities, its contract (input, output, and a checkable "done when"),
and the real constraints with their reasons. It carries no step-by-step procedure (that
belongs in a skill, preloaded through `skills:` when the agent always needs it) and no
per-agent error section (failure policy lives once, in the orchestrator). In team mode, add a
**team communication** section: who it messages, who messages it, and what it claims from
the shared task list. The
definition template and worked agent files are in `references/agent-design-patterns.md` and
`references/team-examples.md`.

**Model and effort.** Default each agent to `model: inherit` so it follows the session's
model. Tune the role with `effort` (`low` … `max`) rather than by switching models: effort is
what trades thinking depth against latency and cost on current models. Judgment roles —
review, design, QA, integration — take `high` or `xhigh`; reading, collection, and formatting
roles take `low` or `medium`. Set `model` to an alias (`opus`, `sonnet`, `haiku`) only when a
role must run on a different model than the session. Aliases track the recommended version,
while a full model id pins one release and ages with it.

**If the team includes a QA agent.** Use the `general-purpose` type (`Explore` is read-only
and cannot run validation). Make its core method *cross-boundary comparison* — read both
sides of a contract together (the producer and the consumer), not each in isolation — and
run it incrementally as each module lands, not once at the end. The full methodology,
boundary-bug patterns, and a QA agent template are in the `qa-agent-guide` reference under
the `harness-review` skill.

## Step 4: Create the skills

Create each skill the agents use at `.claude/skills/{name}/SKILL.md`. The authoring guide —
description writing, body principles, progressive disclosure, data-schema standards — is in
`references/skill-writing-guide.md`. The essentials:

- **Description.** It is the only trigger mechanism. Write it to be specific about what the
  skill does and when it should fire, slightly pushy to offset conservative triggering, and
  worded to stay clear of skills that should *not* fire on the same request.
- **Body.** Explain the *why* rather than issuing bare "ALWAYS/NEVER" rules — an agent that
  understands the reason handles edge cases correctly. Keep it lean (aim under 500 lines;
  move detail to `references/`). Generalize to the principle instead of overfitting to one
  example. Write imperatively.
- **Progressive disclosure.** Metadata is always in context; the body loads on trigger;
  `references/` load only when needed. Split large or domain-specific detail into
  `references/` so only the relevant file loads.
- **Linking.** One agent uses one or more skills; a skill may be shared across agents. The
  skill holds *how*; the agent holds *who*.

Two skills are generated from templates rather than designed per project:

- **`{domain}-visuals`** — only when the visuals sub-step returned a stack. Fill
  `references/visual-skill-template.md` from the visual stack context. It records the project's
  **choices** — stack, patterns, the user's own patterns verbatim, style priority, output
  paths, the review-loop shape, the share-consent and cost-approval rules — and **defers to each
  tool's own skill or `--help` for how to operate it**. Never copy a tool's commands or flags
  into it: tool instructions drift faster than the harness is reviewed.
- **`{domain}-setup-check`** — whenever `tools.md` has at least one row. Fill
  `references/setup-check-template.md`. It is **self-contained**: it reads `tools.md` and runs
  inline presence checks, and hands off to the plugin's `harness-doctor` for the full check when
  the agentic-harness plugin is installed. A teammate without the plugin still gets a working
  check and an optional install hint.

## Step 5: Build the orchestrator and register the pointer

The orchestrator is a skill whose subject is the team: which agents take part, what each
produces, how outputs flow, and how failures are handled. The single contract-first template,
plus the mechanics block to inline for the chosen mode (subagent, team, or hybrid), is in
`references/orchestrator-template.md`. Specify each phase's owner, inputs, outputs, and
"done when". Leave the steps inside a phase to the model.

Build into the orchestrator:

- **An intake-and-triage first phase**, because the orchestrator is the repo's entry point and
  runs for every prompt: it triages first — a trivial or out-of-domain request is answered
  directly and stops there; in-domain work then goes through the context check (initial run vs.
  follow-up vs. partial re-run, branching on whether `_agents_workspace/` already exists). This
  triage is what makes the `CLAUDE.md` hard gate practical — it routes every prompt without
  spinning up a team for trivia.
- **An entry-point description** that opens by stating the orchestrator is the entry point for
  the domain (invoke before responding to any domain request), then carries **follow-up trigger
  keywords** ("re-run", "update", "modify", "supplement", "improve the previous result", and
  everyday domain phrasings). The description backs the `CLAUDE.md` directive; without the
  follow-up keywords the harness goes unused after its first run.
- **Data-passing** stated explicitly, matched to the mode — see
  `${CLAUDE_PLUGIN_ROOT}/shared/execution-modes.md`.
- **Error handling** that does not assume success: retry once, then proceed without the
  missing result and note the omission; never delete conflicting data — record it with its
  source.
- **The tools registry**, when tool discovery (Step 1b) has run: it lives in this
  orchestrator's `references/` directory as `tools.md`, and agents and skills reference tools
  by role from it.
- **Routing to the template skills**, when they were generated: intake routes "show me / draw /
  mock up / visualise" requests and any phase whose output a person must review visually to
  `{domain}-visuals`; it routes "check my setup / why is tool X unavailable / onboard this
  machine" to `{domain}-setup-check`. Add both phrasings to the orchestrator's trigger keywords.
- **SDD coordination**, when Step 0 recorded an SDD coordination context: splice the addenda from
  `references/orchestrator-template.md` (SDD coordination section) into the orchestrator's phase 0,
  prepare, and integrate phases, **inlining the system's concrete artifact paths and entry point** —
  the orchestrator cannot read the shared file at runtime. Mark each phase as delegated
  (`→ SDD: {system}`) or orchestrator-owned. The model is in
  `${CLAUDE_PLUGIN_ROOT}/shared/sdd-coordination.md`.
- **Tracker coordination**, when Step 0 recorded a tracker coordination context: splice the
  addenda from `references/orchestrator-template.md` (Tracker coordination section) into the
  orchestrator's phase 0 and integrate phases, **inlining the tracker's concrete commands** (the
  ready-work query, the create command, the status write-back). The model is in
  `${CLAUDE_PLUGIN_ROOT}/shared/tracker-coordination.md`.
- **Tracker-sync write-through**, when the dual-tracker sync sub-step generated artifacts:
  splice **Addendum T4** (Tracker coordination section of
  `references/orchestrator-template.md`) immediately after T3, so the integrate phase invokes
  the generated `tracker-sync` skill in `scoped` mode for the items it just wrote back. The
  sync model is in `${CLAUDE_PLUGIN_ROOT}/shared/tracker-sync-protocol.md`.

When extending rather than building new, modify the existing orchestrator — do not create a
second one. Reflect a new agent in the team composition, task assignment, data flow, and
trigger keywords.

**Verify generation before declaring it complete.** After writing the generated artifacts,
run the checker against the project:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/harness-setup/scripts/check-generated.sh "$PWD"
```

It is read-only and fails on any unsubstituted template slot, any `${CLAUDE_PLUGIN_ROOT}`
reference, an agent or skill file without `name` + `description` frontmatter, a
`.claude/commands/` directory, or a CLI flag copied into the visuals skill. Any failure blocks
Step 6: fix the file and re-run until it passes. Generated files must be self-contained,
because a leaked placeholder or plugin path surfaces later inside the target project, at worst
in a scheduled headless run that fails with nobody watching.

Then **register the pointer** in the project's `CLAUDE.md`: goal, the **entry-point directive**
(the hard gate that makes the orchestrator the single entry point — every prompt routes through
it before any response), and the change-history table — and nothing the file system already
holds. The convention and the template are in `${CLAUDE_PLUGIN_ROOT}/shared/claude-md-pointer.md`.

## Step 6: Record the change in history

Every write to the harness appends a row to the change-history table in `CLAUDE.md`
(`Date | Change | Target | Reason`). This is a required step, not optional — it is how
evolution stays visible and regressions stay catchable. The table format is in
`${CLAUDE_PLUGIN_ROOT}/shared/claude-md-pointer.md`.

## Step 7: Capture feedback

A harness is a system that keeps changing, not a one-time artifact. After a run, offer the
user the chance to feed back ("anything to improve in the result, the team, or the
workflow?"). If there is none, move on — do not force it. When there is, route it to the
right place: output quality → the relevant skill; missing role → a new agent definition;
wrong order → the orchestrator; missing trigger → a description. The routing table and the
evolution triggers (recurring feedback, repeated failures, the user bypassing the
orchestrator) are in `references/maintenance.md`.

Some feedback is not about *this* harness but about the **tool that built it** — a confusing
step, a missing capability, a bug in the plugin itself. That belongs upstream, not in the
project's files. When the feedback is of that kind, offer to run `harness-feedback`: it runs a
short kaizen retrospective and, with the user's explicit consent, files a privacy-safe GitHub
issue on the agentic-harness repo. Offering is the default; a "no" is fine, and nothing is filed
without approval.

## Deliverable checklist

Before calling a setup or change complete:

- [ ] The full change manifest (agents / skills / orchestrator / pointer / tools to create /
      update / remove / install / uninstall) was formally approved before any write.
- [ ] `scripts/check-generated.sh` passes on the project (placeholders, self-containment,
      frontmatter, no `commands/`, no copied flags).
- [ ] Every agent is a file under `.claude/agents/` — including built-in types.
- [ ] One orchestrator, built from the single template: each phase has an owner, inputs,
      outputs, and a "done when"; plus a failure policy and test scenarios.
- [ ] Execution mode is stated (team / subagent / hybrid; per-phase if hybrid) with exactly the
      matching mechanics inlined, and the subagent fallback covered whenever a team is used.
- [ ] Each agent sets `effort` for its role, and `model` is `inherit` unless the role needs a different model (then an alias, not a pinned id).
- [ ] No conflict with existing agents or skills.
- [ ] Skill and orchestrator descriptions are pushy and include follow-up keywords.
- [ ] The orchestrator description opens by asserting it is the entry point for the domain
      (invoke before responding to any domain request).
- [ ] Each SKILL.md body is within ~500 lines; overflow moved to `references/`.
- [ ] The orchestrator's first phase is intake & triage: it short-circuits trivial / off-domain
      requests, then runs the context check (initial / follow-up / partial) for in-domain work.
- [ ] If an SDD system is present: the orchestrator activates it via a contextual prompt and resumes
      on hand-back, every phase has exactly one owner, and no SDD artifact is copied into
      `_agents_workspace/`.
- [ ] If a tracker is present: phase 0 pulls ready work or creates the issue, integrate writes
      status back, each item's work state has exactly one owner, and no issue content is copied
      into `_agents_workspace/`.
- [ ] If the dual-tracker sync sub-step ran: it was offered only because both an agentic and a
      human tracker are present/declared; the sync preflight validated both entry points before
      anything was generated; the sync config is complete (confirmed state table, intake filter,
      backfill choice, designated branch, cadence, item cap); and every schedule row was
      approved in the manifest as an environment-level change.
- [ ] The `CLAUDE.md` pointer is registered (goal + entry-point directive (hard gate) + change
      history; plus the spec-process and issue-tracking lines when those systems are present).
- [ ] The change-history table records this change.
- [ ] The user was asked whether to run tool research (and, on an existing harness, tool
      maintenance), and the answer was recorded — whatever they chose.
- [ ] If tool discovery ran: nothing was adopted without explicit approval, and accepted
      tools are registered by role (with alternatives) in the orchestrator's `tools.md`.
- [ ] Every install row was pinned and approved one command at a time, with provenance shown.
- [ ] If the visuals sub-step returned a stack: `{domain}-visuals` exists, embeds the user's
      patterns verbatim, and records choices rather than tool instructions.
- [ ] If `tools.md` has rows: `{domain}-setup-check` exists and works without the plugin.

## References

- `references/agent-design-patterns.md` — execution-mode comparison, the six architecture
  patterns, agent-split criteria, the agent-definition template.
- `references/team-examples.md` — worked agent teams across generic domains, with full
  sample agent files.
- `references/orchestrator-template.md` — orchestrator templates by mode, with data-passing,
  error handling, and test scenarios.
- `references/skill-writing-guide.md` — skill authoring: descriptions, body style,
  progressive disclosure, data-schema standards.
- `references/maintenance.md` — extending an existing harness (the extension matrix),
  applying a review context, syncing drift, feedback routing, and periodic tool review.
- `references/tool-discovery.md` — the optional, on-request tool-discovery step: the
  search subagent's context, the explicit-acceptance flow, and the `tools.md` registry schema.
- `references/visual-skill-template.md` — the generated `{domain}-visuals` skill.
- `references/setup-check-template.md` — the generated, self-contained `{domain}-setup-check`
  skill.
- `scripts/check-generated.sh` — the read-only lint run at the end of Step 5.
- `visual-advisor` and `harness-doctor` (sibling skills) — the visual stack choice and the
  read-only system check with the install safety contract.
- `references/tracker-sync-template.md` — what the dual-tracker sync sub-step generates: the
  `tracker-sync` skill, agent, and sync-config templates, the elicitation guidance, and the
  schedule-registration block per venue.
- `${CLAUDE_PLUGIN_ROOT}/shared/harness-model.md`,
  `${CLAUDE_PLUGIN_ROOT}/shared/execution-modes.md`,
  `${CLAUDE_PLUGIN_ROOT}/shared/claude-md-pointer.md` — shared concepts.
- `${CLAUDE_PLUGIN_ROOT}/shared/detection-signatures.md` — how to recognise an installed SDD
  system or issue tracker (shared with `spec-advisor` and `tracker-advisor`);
  `${CLAUDE_PLUGIN_ROOT}/shared/coordination-protocol.md` — the generic coordination protocol;
  `${CLAUDE_PLUGIN_ROOT}/shared/sdd-coordination.md` and
  `${CLAUDE_PLUGIN_ROOT}/shared/tracker-coordination.md` — the per-area instances with their
  per-system coordination maps;
  `${CLAUDE_PLUGIN_ROOT}/shared/tracker-sync-protocol.md` — the dual-tracker sync model
  (lanes, state store, fingerprints, concurrency, failure rules, per-SaaS map).
