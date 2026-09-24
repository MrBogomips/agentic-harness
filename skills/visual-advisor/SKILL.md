---
name: visual-advisor
description: "Choose and set up the visual tooling for a project's agentic harness — which review surface (lavish, visual-explainer, static files) and which asset generators (image APIs, diagram tools, design MCPs) fit the project's domain — presenting domain-specific pros and cons so the user decides. Use when harness-setup reaches its visuals sub-step, when asked which visual tools a harness should use, when adding a visual assistant or visual-asset capability to a harness, or when comparing lavish with its alternatives for a project. Scans first for visual tooling already present and reuses it. Not for producing a visual — to draw a diagram, mockup, chart, or image, use the installed tool itself (lavish, dataviz, plantuml, an image skill). Does NOT build the .claude/ harness (that is harness-setup), does NOT check what is installed on the machine (that is harness-doctor), and does NOT choose a spec system or tracker (spec-advisor, tracker-advisor)."
model: inherit
---

# Visual advisor — choose the visual tooling for a harness

A harness often produces things a person must *look at*: an architecture, a plan, a UI, a report,
a brand asset. Text is a poor medium for most of those. This skill helps the user choose the
**visual stack** a generated harness will use — one review surface, a few generators, and a style
source — with a pros/cons comparison grounded in the project's domain. It never produces a visual
itself and never installs anything itself: the stack is handed back to `harness-setup`, which
registers it in `tools.md` and installs through the approved change manifest.

It is offline-first. The curated catalog in `references/visual-tools.md` is enough to scan,
compare, and name an install source; the network is reached only with the user's say-so.

## What this skill is not — and which skill to use instead

| Does NOT | Use instead |
|---|---|
| Draw a diagram, mockup, chart, slide, or image | the **installed tool** (lavish, dataviz, plantuml, an image skill) |
| Build or change the `.claude/` harness | **harness-setup** — it generates the `{domain}-visuals` skill |
| Check which plugins, skills, MCP servers, or CLIs are installed | **harness-doctor** |
| Install or uninstall a tool | **harness-setup** Step 2b manifest, under the install safety contract |
| Choose a spec system or an issue tracker | **spec-advisor** / **tracker-advisor** |
| Replace visual tooling the project already uses | nothing — the scan reports and reuses it |
| Write to `CLAUDE.md` | nothing — the registry row is the record |

Visuals are a **tool role**, not a process layer: nothing in the workflow hands off to a
"visual system" and waits for it to hand back. Agents call a visual tool when their output
benefits from one. That is why the chosen stack lives in the harness `tools.md` registry, under
the roles `visual-review-surface` and `visual-generator`, like any other tool.

## The flow

Each step is an off-ramp: a "no" ends the run cleanly.

### Step 0 — Take the context

When invoked from `harness-setup`, reuse the domain profile from its Step 1 (domain, task types,
stack, who reads the output). Standalone, build a quick profile: read the README and the manifest,
and ask one question — who looks at what this project produces?

### Step 1 — Scan for visual tooling already present

Using the "Visual tooling" section of `${CLAUDE_PLUGIN_ROOT}/shared/detection-signatures.md`, look
for what the project and the machine already have: a `.lavish/` directory, `*.puml` sources, a
`DESIGN.md` or design tokens, a Tailwind config, brand assets, visual skills and plugins already
installed. For machine-level presence, ask `harness-doctor` rather than parsing config files here.

What is found is **reused, not replaced**: it enters the comparison as the incumbent, and the
default recommendation keeps it unless the user's needs rule it out.

### Step 2 — Offer, with a utility briefing

This sub-step is **always offered** — but briefly, and a single "no" ends it without the long
version. The offer is a short briefing, not a sales pitch:

1. **Where visuals would earn their place in this domain** — two or three concrete patterns from
   the domain→pattern map in `references/visual-tools.md` (for an architecture-heavy service:
   component and sequence diagrams reviewed before a change; for a product UI: clickable mockups
   before implementation).
2. **Where they would not** — the anti-patterns for this domain (a CLI library rarely needs brand
   assets; a diagram nobody maintains goes stale faster than prose).
3. **An invitation** — ask whether the user has visual patterns they already rely on, or tools
   they would like in the harness. Record their answer **verbatim**; it is embedded in the
   generated `{domain}-visuals` skill and outranks the catalog's defaults.

### Step 3 — Build the needs profile

Gather, by asking or inferring from Steps 0–2:

- **Asset types** — diagrams, plans and comparisons, UI mockups and prototypes, data dashboards,
  slides, raster images (illustrations, logos, social assets).
- **Feedback loop** — does the user want to annotate and iterate in the browser, or is a static
  file reviewed in chat or a pull request enough?
- **Key and cost tolerance** — are paid image APIs acceptable at all, and up to what per-run cost?
- **Offline and privacy constraints** — may project content leave the machine? (A prompt to an
  image API, or a published share link, can carry code or client data.)
- **Design system** — is there one to honour (tokens, a `DESIGN.md`, brand guidelines)?
- **Environment** — can a local browser open here? Check `$CI`, `$SSH_CONNECTION`, whether `open`
  (macOS) or `xdg-open` (Linux) exists, and on Linux `$DISPLAY` / `$WAYLAND_DISPLAY`. When no
  browser can open (CI, SSH, a devcontainer, a web session), a browser review loop is **not**
  recommended; the fallback is static SVG/PNG/HTML under the project's docs, reviewed in chat or
  a pull request.

### Step 4 — Recommend a stack (offline)

From `references/visual-tools.md`:

1. **Filter** — drop every tool that fails a hard constraint (needs a key when keys are ruled out;
   needs a browser when none can open; sends content off-machine when that is forbidden).
2. **Score** the survivors on the fixed criteria — feedback loop, asset coverage, key/cost,
   offline, privacy, maturity, install footprint — each as **fit / partial / no** against the
   needs profile. Fixed criteria keep the comparison reproducible across runs.
3. **Present a domain-specific pros/cons table**: the incumbent first, then two or three
   candidates per slot. Each row says why it fits *this* project, not in general. Mark any profile
   past its `verify_by` date as **unverified**.
4. **Offer an online refresh** (a search for newer tools, or a fetch of a candidate's official
   repo) — run it **only on an explicit yes**; offline or on a stall, fall back to the catalog.
5. **The user picks** — one review surface, zero to two generators, one style source. Do not
   choose on their behalf.

### Step 5 — Hand back to harness-setup

Return a **visual stack context**:

```text
review-surface: {tool} (alternative: {tool or "static files"})
generators:     {tool, ...} (alternative per generator)
style-source:   {user request → project design system → tool default}
output-dir:     {path, e.g. .lavish/ or docs/assets/}
patterns:       {domain patterns chosen in Step 2}
user-patterns:  {verbatim from Step 2, or "none"}
environment:    {browser available | static-only}
cost-policy:    {none | approve each paid generation above {amount}}
share-policy:   never publish without per-page consent
```

`harness-setup` registers the tools by role in `tools.md` (with `Kind` and a pinned `Source`),
turns anything missing into `install` rows in its Step 2b manifest, and generates the
`{domain}-visuals` skill from this context. Nothing is installed from here.

## Error handling and graceful degradation

- **Offline, or a refresh stalls** — use the catalog; the offline path is complete on its own.
- **An install fails later in harness-setup** — the stack falls back to the key-free tools
  already present (lavish, dataviz, plantuml, or static files); tell the caller which role lost
  its preferred tool, so the registry records the alternative as active.
- **No browser can open** — recommend the static path; never recommend a review loop that
  cannot run where the harness runs.
- **User declines at any step** — stop cleanly; no `{domain}-visuals` skill is generated.

## References

- `references/visual-tools.md` — the curated catalog (per-tool profiles with install source,
  cost, privacy caveats, maturity, and verification dates), the scoring criteria, the
  domain→pattern map with anti-patterns, and the online policy.
- `${CLAUDE_PLUGIN_ROOT}/shared/detection-signatures.md` — the "Visual tooling" signatures used
  by the Step 1 scan.
