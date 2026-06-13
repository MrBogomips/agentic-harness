# Feedback format — the standard for tool-improvement issues

This file is the **single source of truth** for the feedback a harness run can send back
upstream to improve the `agentic-harness` tool itself. Three things mirror it and must stay in
sync with it:

- the GitHub issue template — `.github/ISSUE_TEMPLATE/feedback.md`,
- the skill that drafts and files the issue — `harness-feedback`,
- the CI check that validates a submitted issue — `.github/workflows/feedback-check.yml`.

`tests/validate-feedback.sh` fails the build if the three drift apart, so change this file first
and let the others follow.

## Where the issue goes

Feedback is always filed on the **upstream plugin repository**, never the end user's own repo —
the harness runs inside someone else's project, but the improvement is to *this tool*.

- **Repository:** `MrBogomips/agentic-harness`
- **Label (auto-applied by the template; the CI check filters on it):** `feedback`
- **Title prefix:** `[feedback] `

## The fields

Every feedback issue is a set of `## ` sections. The headings are parsed verbatim by the CI
check, so they must match exactly. Eight sections are **mandatory**; two are optional.

| Section | Mandatory | What it holds | Where the value comes from |
|---|---|---|---|
| `Summary` | yes | One line naming the feedback or suggestion. | The reporter. |
| `Type` | yes | One of `bug` · `friction` · `enhancement` · `docs` · `question`. | The reporter. |
| `What was done` | yes | Which skill/command ran and the high-level outcome (e.g. "ran harness-setup, new build, 3-agent team"). | Fresh session context if filing right after a run; else the `CLAUDE.md` change-history table; else ask. |
| `Choices made` | yes | The decisions taken during execution: architecture pattern, execution mode, tools accepted/rejected, SDD/tracker coordination, manifest amendments. | The Step 2b manifest / session context; else ask. |
| `Expected outcome` | yes | What the reporter expected — the *expected* behaviour for a bug, or the *desired* result / "what good looks like" for an enhancement, docs, or friction item. | The reporter. |
| `What happened / friction` | yes | The *actual* result and where friction occurred — the counterpart to `Expected outcome`. | The reporter + session. |
| `Suggested improvement` | yes | The concrete change being proposed. | The reporter. |
| `Environment` | yes | Plugin version, Claude Code version, OS. Redacted of anything project-identifying. | Auto: `version` from `.claude-plugin/plugin.json`, `claude --version`, `uname -sr`. |
| `Affected area` | no | The harness part the feedback bears on: a skill / step / agent / orchestrator. | Session context. |
| `Additional context` | no | Anything else worth attaching. | The reporter. |

`Expected outcome` sits between `Choices made` and `What happened / friction` on purpose — the
two form the expected-vs-actual pair that makes a report actionable.

<!-- mandatory-sections:start (canonical list — the issue template and the CI check mirror this) -->
- Summary
- Type
- What was done
- Choices made
- Expected outcome
- What happened / friction
- Suggested improvement
- Environment
<!-- mandatory-sections:end -->

## Redaction policy

The harness runs inside a private project, but feedback lands on a **public** repo. Separate the
tool-improvement signal from the project's specifics, and redact the specifics by default. This is
not optional and it is not the reporter's burden to remember — the drafting skill applies it before
showing the issue for approval.

**Strip or generalize:**

- repository and organization names, and the project's product/brand names;
- absolute filesystem paths → replace with `<path>`;
- proprietary domain or business terms (the *kind* of system is fine; the company's nouns are not);
- secrets, tokens, credentials, internal hostnames and URLs;
- names of people.

**Keep — this is the useful signal:**

- the generic tech stack (languages, frameworks, datastore *types*);
- the harness mechanics — which skill/step ran, which architecture pattern and execution mode were
  chosen, which coordination (SDD/tracker) was involved;
- the nature of the friction or the bug, and what was expected instead.

When in doubt, generalize: "a monorepo with a Python API and a React front end" carries the signal;
the repo's name does not.

## The fill-ready body skeleton

This is the canonical body. `.github/ISSUE_TEMPLATE/feedback.md` mirrors it for the GitHub UI; the
`harness-feedback` skill fills it and writes it to a temp file for `gh issue create`. Each section
is seeded with an HTML-comment hint — the CI check treats a section whose only content is a comment
(or empty, `_No response_`, or `TODO`) as **unfilled**, so real text must replace the hint.

```markdown
## Summary
<!-- One line: what is this feedback or suggestion about? -->

## Type
<!-- One of: bug | friction | enhancement | docs | question -->

## What was done
<!-- Which skill/command ran, and the high-level outcome. -->

## Choices made
<!-- Key decisions during execution: architecture pattern, execution mode, tools accepted/rejected, SDD/tracker coordination. -->

## Expected outcome
<!-- What you expected: the expected behaviour (bug) or the desired result / "what good looks like" (enhancement/docs/friction). -->

## What happened / friction
<!-- The actual result and where the friction occurred. -->

## Suggested improvement
<!-- The concrete change you'd propose. -->

## Environment
<!-- Plugin version, Claude Code version, OS. Redacted of anything project-identifying. -->

## Affected area
<!-- Optional: the harness part this bears on — a skill / step / agent / orchestrator. -->

## Additional context
<!-- Optional: anything else worth attaching. -->
```
