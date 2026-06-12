# Skill writing guide

How to write the skills a generated harness uses, so they trigger reliably and earn their
context cost. Supplements Step 4.

## Table of contents

- [Skill writing guide](#skill-writing-guide)
  - [Table of contents](#table-of-contents)
  - [1. Writing the description](#1-writing-the-description)
  - [2. Body style](#2-body-style)
  - [3. Output formats and examples](#3-output-formats-and-examples)
  - [4. Progressive disclosure](#4-progressive-disclosure)
  - [5. When to bundle a script](#5-when-to-bundle-a-script)
  - [6. Data-schema standards](#6-data-schema-standards)
  - [7. What to leave out](#7-what-to-leave-out)

---

## 1. Writing the description

The description is the only thing that decides whether a skill triggers. The model judges
from the name and description alone, and it tends to skip a skill for a task it thinks it can
handle bare-handed. So:

1. Say both **what the skill does** and **the specific situations that should trigger it**.
2. Mark the boundary — name the near-miss cases where a *different* tool is the right fit, so
   this skill does not fire on them.
3. Lean slightly pushy, to offset the conservative default.

**Weak:** `"A skill that processes data"` — which data, which task? Too vague to trigger.

**Strong:** `"All spreadsheet operations — add columns, compute formulas, format, chart,
clean data — for .xlsx / .csv / .tsv. Use whenever the user mentions a spreadsheet file,
even in passing. Not for a Word document or a PDF: use the matching skill for those."`

The strong version enumerates concrete actions, states the trigger, and draws the boundary.

## 2. Body style

**Explain the why.** A rule the agent understands generalizes; a bare command does not.

Weak:
```text
ALWAYS use a table-aware extractor. NEVER use a plain text extractor for tables.
```
Strong:
```text
Use a table-aware extractor for tables: a plain text extractor loses the row and column
structure, while a table-aware one recognizes cell boundaries and returns structured rows.
```

**Generalize, don't overfit.** Fix at the level of the principle, not the one example that
failed.

Weak: `If a column is named "Q4 Revenue", convert it to numbers.`
Strong: `If a column name implies a numeric quantity (revenue, amount, count), convert it to
a number; if conversion fails, keep the original value.`

**Write imperatively.** A skill is an instruction sheet: "do X", not "the skill does X".

**Spend context deliberately.** The window is shared. For each sentence ask: does the agent
already know this (cut it), would it err without it (keep it), would one example replace the
explanation (swap it)?

## 3. Output formats and examples

When the deliverable's shape matters, show the template:

```text
## Report structure
# {Title}
## Summary
## Findings
## Recommendations
```

Keep it short — a concrete example teaches faster than a long spec. For transformations,
pair input with output:

```text
Input:  Add token-based user authentication
Output: feat(auth): add token-based authentication
```

## 4. Progressive disclosure

A skill loads in three stages: metadata (always in context), the SKILL.md body (on trigger),
and `references/` files (only when read). Use the stages:

- As the body nears ~500 lines, move detail into `references/` and leave a one-line pointer
  that says when to read it.
- Give any reference over ~300 lines a table of contents at the top.
- Split domain- or framework-specific variants into separate reference files, so only the
  relevant one loads:

```text
deploy-skill/
├── SKILL.md            (workflow + which file to load)
└── references/
    ├── provider-a.md
    ├── provider-b.md
    └── provider-c.md
```

## 5. When to bundle a script

Watch the agents' transcripts during testing. Bundle when a pattern repeats:

| Signal | Action |
|--------|--------|
| The same helper script is written in every test run | bundle it under `scripts/` |
| The same dependency is installed every time | state the install step in the skill |
| The same multi-step approach recurs | write it up as a standard procedure in the body |
| The same workaround follows the same error every time | document the issue and its fix |
| The same document or report is read or produced | write it up and define a json data schema for input/output payload to interact with it |

A bundled script must pass an execution test of its own.

## 6. Data-schema standards

When a harness tests its own generated skills, a shared schema keeps results comparable.

Test-case metadata:
```json
{
  "eval_id": 0,
  "eval_name": "descriptive-name",
  "prompt": "the user's task prompt",
  "assertions": ["the deliverable contains X", "a file in format Y was produced"]
}
```

Assertion-based grading — use the field names `text`, `passed`, `evidence` exactly:
```json
{
  "expectations": [
    { "text": "a margin column was added", "passed": true, "evidence": "column E holds margin_pct" }
  ],
  "summary": { "passed": 2, "failed": 1, "total": 3, "pass_rate": 0.67 }
}
```

Timing — capture from the completion notification immediately; it cannot be recovered later:
```json
{ "total_tokens": 84852, "duration_ms": 23332 }
```

## 7. What to leave out

- Supplementary docs (README, CHANGELOG, install guides).
- Meta-notes about how the skill was built (test logs, iteration history).
- End-user manuals — a skill is an instruction sheet for an agent, not a human.
- General knowledge the model already has.
