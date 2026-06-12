# CLAUDE.md

Guidance for working in the agentic-harness plugin repository.

## Repository structure

This is a single-plugin repository: the repo root is the plugin. `.claude-plugin/` holds both `plugin.json` (the plugin manifest) and `marketplace.json` (a single-plugin marketplace named `mrbogomips-harness`, whose one entry points at `./`).

- **Skills** — `skills/*/SKILL.md` (harness-setup, harness-review, spec-advisor, tracker-advisor)
- **Shared knowledge** — `shared/*.md`, referenced from skills as `${CLAUDE_PLUGIN_ROOT}/shared/...`

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
