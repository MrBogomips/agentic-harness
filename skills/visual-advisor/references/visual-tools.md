# Visual tools — curated catalog

The recommend knowledge behind flow Steps 2–4: the per-tool profiles, the scoring criteria, the
domain→pattern map, and the online policy.

This catalog is **deliberately small**. Visual tooling moves fast and third-party repos rot, so
the catalog holds a handful of verified profiles plus a "see also" list, not an exhaustive survey.
Every profile carries `last_verified` and `verify_by` (90 days later). Past `verify_by`, label the
profile **unverified** in the comparison and offer the online refresh — do not silently trust it.

Install sources are the offline baseline. When the user **selects** a tool, confirm the current
source from its official repository (online form b) before it becomes a manifest row, and **pin**
it: a version (`pkg@x.y.z`), a tag, or a commit. Never register `npx -y pkg` without a version —
that runs whatever is newest on every call.

## Slots

A visual stack has three slots:

- **Review surface** (exactly one) — where the user sees and responds to what the harness made.
- **Generators** (zero to two) — what produces assets the review surface cannot draw itself.
- **Style source** (one) — user request → project design system → tool default, in that order.

## Per-tool profiles

### lavish — review surface
- **Official repo:** github.com/kunchenguid/lavish-axi (MIT)
- **Kind:** skill + CLI. **Install source:** the skill via the `skills` installer from
  `kunchenguid/lavish-axi`, **resolved to a pinned form before it becomes a manifest row** — a
  pinned installer version and a tag or commit of the repo (confirm the ref syntax with the
  authoritative fetch; an unpinned `npx skills add owner/repo` is not an acceptable row). The
  CLI runs as `npx lavish-axi@<version>` (0.1.78 verified).
- **Produces:** HTML pages — diagrams, tables, comparisons, plans, code diffs, explanations,
  slides, structured input forms, UI mocks with embedded screenshots. Diagrams can become editable
  whiteboards. No raster generation.
- **Feedback loop:** yes, two-way — the user annotates elements or text in the browser, the agent
  collects the feedback and replies in the page; a layout checker reports overflow and overlap.
- **Key / cost:** none. Needs Node and network for CDN assets.
- **Offline:** partial (CDN styles and fonts). **Browser:** requires a local one.
- **Privacy:** local by default; its **share** feature publishes a page to a third-party host and
  is **public unless made private** — never share without per-page consent.
- **Style:** honours the user's request, then the project's design system, then its own default.
- **Maturity:** active, widely starred. **Caveat:** the installed skill text can lag the CLI;
  the CLI's own `--help` is authoritative, which is why generated skills defer to it.
- **last_verified:** 2026-09-24 · **verify_by:** 2026-12-23

### visual-explainer — review surface (one-way)
- **Official repo:** github.com/nicobailon/visual-explainer (MIT)
- **Kind:** plugin / skill (also an MCP server). **Install source:** per the repo README —
  confirm via authoritative fetch before adding a manifest row.
- **Produces:** HTML explainers, zoomable diagrams, diff and plan reviews, slide decks, PPTX export.
- **Feedback loop:** no — it opens the page, but feedback returns through chat.
- **Key / cost:** none. **Browser:** opens one, but the output is a static file that also works
  without one.
- **Privacy:** local files.
- **Maturity:** active, the most-starred in its class; runs in several agent tools.
- **last_verified:** 2026-09-24 · **verify_by:** 2026-12-23

### Static files — review surface (fallback)
- **Kind:** none — SVG/PNG/HTML written under the project's docs (e.g. `docs/assets/`).
- **Feedback loop:** through chat or a pull request review.
- **Key / cost:** none. **Offline:** yes. **Browser:** not required — the choice for CI, SSH,
  devcontainers, and web sessions.
- **last_verified:** n/a (no external dependency)

### dataviz — generator (charts, dashboards)
- **Kind:** built-in Claude Code skill. **Install source:** none — present when the host ships it.
  It has no file on disk, so confirm it from the session's own skill list, and register it with
  `Kind: remote` so harness-doctor reports it as unknown-remote rather than missing.
- **Produces:** charts, KPI tiles, dashboards as HTML/SVG or plotting code.
- **Key / cost:** none. **Offline:** yes. **Privacy:** local.
- **last_verified:** 2026-09-24 · **verify_by:** 2026-12-23

### PlantUML — generator (diagrams as code)
- **Kind:** CLI (`plantuml`, needs Java) and optionally a Claude Code plugin with authoring skills.
  **Install source:** CLI from the OS package manager; a plugin only if one is already registered
  in a known marketplace.
- **Produces:** UML, C4, ER, sequence, mind-map, Gantt diagrams as PNG/SVG/PDF from versioned text.
- **Feedback loop:** no (pair with a review surface). **Key / cost:** none. **Offline:** yes.
- **Best-fit:** diagrams that must live in the repo and be diffed.
- **last_verified:** 2026-09-24 · **verify_by:** 2026-12-23

### banana-claude — generator (raster images)
- **Official repo:** github.com/AgriciDaniel/banana-claude (MIT)
- **Kind:** plugin. **Install source:** its plugin marketplace per the README — confirm via
  authoritative fetch; pin to a release tag.
- **Produces:** product and campaign images, illustrations, social assets, image edits.
- **Feedback loop:** partial — shows a plan and a cost estimate before each paid call; review and
  regenerate in chat, or embed the result in the review surface.
- **Key / cost:** **Gemini API key with billing**; every generation costs money.
- **Offline:** no. **Privacy:** prompts leave the machine — never put code, secrets, or client
  data in a prompt without approval.
- **Maturity:** active, released versions.
- **last_verified:** 2026-09-24 · **verify_by:** 2026-12-23

### Figma / Stitch — generator (UI design)
- **Kind:** MCP server (Figma: official plugin or remote MCP; Stitch: a community MCP proxy).
  **Install source:** Figma via its official plugin; Stitch via its npm package, pinned
  (`<pkg>@<version>`), never unpinned `npx -y`.
- **Produces:** UI screens, variants, design systems, component libraries, asset downloads.
- **Feedback loop:** in the design tool itself. **Key / cost:** account and OAuth; plan limits.
- **Offline:** no. **Privacy:** designs live in the vendor's cloud.
- **Best-fit:** projects whose design source of truth is already Figma, or UI-first products.
- **last_verified:** 2026-09-24 · **verify_by:** 2026-12-23

### See also (not profiled — refresh online before recommending)

- **opc-skills** (github.com/ReScienceLab/opc-skills) — logo, icon, and banner variants with an
  HTML gallery for picking; Gemini / Recraft / remove.bg keys.
- **inference-sh skills** (github.com/inference-sh/skills) — one broker for many image models
  (gpt-image, FLUX, Recraft, Gemini); paid account.
- **generate-image** (github.com/K-Dense-AI/scientific-agent-skills) — many image models via
  OpenRouter; science-oriented.
- **canvas-design, theme-factory, algorithmic-art** (github.com/anthropics/skills) — key-free
  posters, themes, and generative art.

## Scoring criteria

Score each surviving candidate against the needs profile as **fit / partial / no**:

| Criterion | Fit means |
|---|---|
| Feedback loop | matches the wanted interaction (two-way, one-way, or static) |
| Asset coverage | produces the asset types the domain needs |
| Key / cost | within the stated tolerance (none, capped, open) |
| Offline | works with the network constraint |
| Privacy | keeps content where the user said it must stay |
| Maturity | maintained, released, verified within `verify_by` |
| Install footprint | the smallest addition that covers the need (reuse > add) |

**Hard constraints filter before scoring**: a tool that needs a key when keys are ruled out, a
browser when none can open, or the cloud when content must stay local is removed, not scored low.

## Selection decision tree

1. **Tooling already present** (Step 1 scan)? → keep it as the incumbent unless a hard
   constraint rules it out.
2. **No browser where the harness runs?** → review surface = static files.
3. **Two-way annotate-and-iterate wanted?** → lavish.
4. **One-way explainers, or multi-agent-tool portability wanted?** → visual-explainer.
5. **Diagrams that must be versioned in the repo?** → add PlantUML.
6. **Data or reporting domain?** → add dataviz.
7. **Raster images, logos, or marketing assets needed and a paid key is acceptable?** → add an
   image generator (banana-claude; refresh the see-also list for alternatives). No key → say what
   is out of reach and offer the key-free see-also skills.
8. **Design source of truth in Figma, or UI-first product?** → add Figma / Stitch.

## Domain → pattern map

| Domain | Patterns worth their cost | Anti-patterns |
|---|---|---|
| Backend / architecture | component, sequence, and state diagrams reviewed before a change; ADR comparison pages | diagrams of every module; pictures no one updates |
| Product / UI | clickable mockups before implementation; variant comparison; screenshot annotation | pixel-perfect mocks for internal tools |
| Marketing / brand | brand kit, logo and social-asset variants with a pick-one gallery | generating images without a brand source |
| Data / reporting | dashboards, KPI tiles, charts in reports | charts where one number would do |
| Documentation | explainers, walkthrough slides, annotated screenshots | decorative illustrations |
| Planning / delivery | plan and comparison pages, decision forms, roadmap timelines | re-drawing plans the tracker already shows |
| CLI / library | usually none — a sequence diagram of a tricky flow at most | brand assets, dashboards |

Use the map to write the Step 2 briefing: two or three patterns that fit, one or two anti-patterns,
then the invitation for the user's own patterns and tools.

## Online policy

The default is **fully offline**. Online access takes two narrow forms, never automatic:

- **(a) Refresh search** — "is there anything newer than the catalog for this need?" Offer it in
  Step 4; run it **only on an explicit yes**. Always offer it when a profile is past `verify_by`.
  Offline or on a stall, fall back to the catalog.
- **(b) Authoritative fetch** — once the user **selects** a tool, fetch its install source and
  license from **its official repository** to confirm the pinned source before it becomes a
  manifest row.
