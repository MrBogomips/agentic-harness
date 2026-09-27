# Visuals skill generation template

What `harness-setup` generates when the Step 1b **visuals sub-step** returned a visual stack
context from `visual-advisor`: the project's `{domain}-visuals` skill. The choice of stack, the
briefing, and the scoring live in `visual-advisor`; this file only turns the returned context
into a skill.

## Generation rules

1. **Choices, not instructions.** The generated skill records what *this project* chose — the
   stack, patterns, the user's own patterns, style priority, output paths, and the policies. It
   **never copies a tool's commands, flags, or playbooks**. For how to operate a tool, it tells
   the agent to invoke that tool's own skill, or read the tool's `--help`, at the moment of use.
   Tool instructions change on the tool's release cadence, not the harness's review cadence; a
   copied flag is a bug waiting for the next release.
2. **Tools by role.** Name `visual-review-surface` and `visual-generator` from the orchestrator's
   `tools.md`, with the registered alternative — never a hard tool name in the procedure. The
   one place a tool name appears is the "current stack" line, which is informational.
3. **User patterns verbatim.** Paste what the user said in the briefing exactly; it outranks the
   defaults and is the part of the skill most likely to be edited later by the user.
4. **Self-contained.** No `${CLAUDE_PLUGIN_ROOT}` path, no reference to plugin files. The Step 5
   placeholder check applies.
5. **Gitignore.** If the review surface writes working files (for lavish, `.lavish/`), ask
   whether they belong in git; if not, add one `.gitignore` manifest row.

## Generated skill — `.claude/skills/{DOMAIN}-visuals/SKILL.md`

````markdown
---
name: {DOMAIN}-visuals
description: "Produce and review the visual assets for {DOMAIN_LABEL} — {ASSET_TYPES} — using the project's chosen visual stack, and iterate on them with the user. Use when a request asks for a visual artifact for {DOMAIN_LABEL} — a diagram, mockup, prototype, chart, dashboard, slide deck, comparison page, or image ('draw a diagram of', 'mock up the', 'visualise the', 'make slides for') — when a harness phase produces output a person should review visually, or to revise a visual made earlier ('update the diagram', 'change the mockup'). Not for printing text output, logs, or code, and not for choosing or installing visual tools — that is harness setup."
model: inherit
---

# {DOMAIN_LABEL} visuals

Visual output for this project goes through one review surface and a small set of generators,
chosen for this domain on {DATE}. Look tools up **by role** in the orchestrator's
`references/tools.md`; if the preferred tool is unavailable, use the registered alternative and
say so.

Current stack (informational — `tools.md` is authoritative):
- Review surface: {REVIEW_SURFACE} — alternative: {REVIEW_ALTERNATIVE}
- Generators: {GENERATORS_OR_NONE}
- Style source: {STYLE_SOURCE}

## When a visual earns its place here

{DOMAIN_PATTERNS}

Skip the visual when: {ANTI_PATTERNS}

### The user's own patterns and tools

{USER_PATTERNS_VERBATIM}

## How to work

1. **Pick the pattern** from the lists above; if the request fits none, ask whether a visual is
   wanted at all before making one.
2. **Operate the tool through its own guidance.** Invoke the `visual-review-surface` tool's own
   skill, or read its built-in help, before using it — do not rely on remembered commands.
   Do the same for any `visual-generator`.
3. **Style, in order:** what the user asks for → the project's design system ({DESIGN_SYSTEM})
   → the tool's default. State which one you used. For UI and page output with no design
   direction, steer away from the generic defaults by name. A vague "avoid a generic look" only
   swaps one default for another. Do not use: {STYLE_AVOID}. When a first render shows another
   default the user dislikes, add it to this list.
4. **Write output to** `{OUTPUT_DIR}`. Assets that other docs link to go under
   `{PUBLISHED_ASSETS_DIR}`.
5. **Review loop:** render → the user reviews and annotates → revise → repeat until the user
   ends the review. {ENVIRONMENT_NOTE}
6. **Embed generated images** in the review surface rather than showing them bare, so they are
   reviewed in context.

## Policies

- **Sharing.** Never publish a visual outside this machine (a share link, an upload, a public
  host) without the user's consent **for that page**. Before sharing, check it for secrets,
  credentials, internal hostnames, and client data, and show the user the destination.
- **Cost.** {COST_POLICY}
- **Privacy.** Never put source code, secrets, or client data into a prompt sent to an external
  image service without the user's approval.
- **Unavailable tool.** If neither the preferred tool nor its alternative is available, say so,
  fall back to a static SVG or HTML file in `{OUTPUT_DIR}`, and suggest running
  `{DOMAIN}-setup-check`.
````

## Filling the placeholders

| Placeholder | From the visual stack context |
|---|---|
| `{DOMAIN}`, `{DOMAIN_LABEL}` | the harness domain slug and its readable name |
| `{ASSET_TYPES}` | the asset types from the needs profile |
| `{DATE}` | the generation date, `YYYY-MM-DD` |
| `{REVIEW_SURFACE}`, `{REVIEW_ALTERNATIVE}` | `review-surface` and its alternative |
| `{GENERATORS_OR_NONE}` | `generators`, each with its alternative, or "none" |
| `{STYLE_SOURCE}`, `{DESIGN_SYSTEM}` | `style-source`; the design system's path, or "none found" |
| `{DOMAIN_PATTERNS}`, `{ANTI_PATTERNS}` | `patterns`, as bullets; the briefing's anti-patterns |
| `{USER_PATTERNS_VERBATIM}` | `user-patterns`, unedited, or "None yet — add your own here." |
| `{OUTPUT_DIR}`, `{PUBLISHED_ASSETS_DIR}` | `output-dir`; the docs asset directory, e.g. `docs/assets/` |
| `{STYLE_AVOID}` | the user's named dislikes from the briefing, plus the common defaults: "a cream or off-white background, italic accent words in headlines, numbered 01/02/03 section labels, monospace labels, pill-shaped buttons". Drop any item the design system itself uses |
| `{ENVIRONMENT_NOTE}` | static-only → "No browser opens where this harness runs: write static files and review them in chat or in the pull request." Otherwise empty. |
| `{COST_POLICY}` | `cost-policy`, e.g. "Paid generation is not used." or "Ask before each paid generation above {amount}; state the estimated cost." |
