# CLAUDE.md

Guidance for working in the agentic-harness plugin repository.

## Repository structure

This is a single-plugin repository: the repo root is the plugin. `.claude-plugin/` holds both `plugin.json` (the plugin manifest) and `marketplace.json` (a single-plugin marketplace named `mrbogomips-harness`, whose one entry points at `./`).

- **Skills** — `skills/*/SKILL.md` (harness-setup, harness-review, harness-feedback, spec-advisor, tracker-advisor)
- **Commands** — `commands/*.md` (`/feedback` — the one deliberate command; named to avoid clashing with the `harness-feedback` skill; everything else is a skill)
- **Shared knowledge** — `shared/*.md`, referenced from skills as `${CLAUDE_PLUGIN_ROOT}/shared/...`
- **GitHub config** — `.github/ISSUE_TEMPLATE/feedback.md` (the feedback issue template) and `.github/workflows/` (`validate.yml` for plugin structure, `feedback-check.yml` for feedback-issue validation)

### Feedback format is single-source-of-truth

`shared/feedback-format.md` is canonical for the tool-feedback format: the mandatory sections, the redaction policy, the upstream repo slug, and the body skeleton. The issue template, the `harness-feedback` skill, and the `feedback-check.yml` CI check all mirror it. `tests/validate-feedback.sh` fails the build if they drift — so edit `shared/feedback-format.md` first, then update the mirrors.

The flow uses two repo labels: `feedback` (marks issues to validate) and `needs-info` (set when an issue is incomplete). The CI bot identifies a feedback issue by the `feedback` label **or** a `[feedback]` title prefix, ensures both labels exist, and applies `feedback` itself — so reporters who cannot set labels (non-collaborators opening via the CLI) are still handled, and a fresh fork self-heals on first use.

## Versioning

`plugin.json` is the source of truth for the plugin version. The `marketplace.json` entry must carry the same version — `tests/validate-versions.sh` enforces the sync. Bump both together.

## Validation

After any change, run:

```bash
bash tests/run-structural-tests.sh
```

This is a strict requirement. No change is complete until validation passes. Requires `jq`.

Before a release or community-marketplace submission, also run:

```bash
claude plugin validate . --strict
```

## Shell script conventions

Scripts must be macOS (BSD) compatible — no `grep -P`, no `head -n -1`, no associative arrays (bash 3.2). Use `grep -E`/`grep -oE` and `awk` instead. Avoid `((VAR++))` with `set -e` (fails when VAR=0); use `VAR=$((VAR + 1))`.

## Git / PR Working Policy
- Worktree usage: disabled
- Worktree location: n/a (topic branch in main checkout)
- Base branch: main
- Recorded on: 2026-06-12
