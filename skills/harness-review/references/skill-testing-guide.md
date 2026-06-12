# Skill testing guide

How to test whether a harness's skills trigger correctly and add value, and how to improve
them. Supplements the validation step.

## Table of contents

1. [Two kinds of evaluation](#1-two-kinds-of-evaluation)
2. [Writing test prompts](#2-writing-test-prompts)
3. [With-skill vs baseline](#3-with-skill-vs-baseline)
4. [Assertion-based scoring](#4-assertion-based-scoring)
5. [Trigger validation](#5-trigger-validation)
6. [The improvement loop](#6-the-improvement-loop)

---

## 1. Two kinds of evaluation

Skill quality is judged two ways, and most skills need both:

| Kind | How | Fits |
|------|-----|------|
| Qualitative | the user reads the deliverable | subjective quality — prose, design, judgment calls |
| Quantitative | assertion-based scoring | objectively checkable results — a file created, data extracted, code generated |

The loop is the same either way: **write a test → run it → evaluate → improve → re-run**.

## 2. Writing test prompts

A test prompt should read like a real request a real user would type — specific and natural.
Abstract prompts ("process the data", "generate a chart") have little test value.

A good prompt carries concrete detail:

```text
In the quarterly sales sheet in my downloads folder, add a margin column from the revenue and
cost columns, then sort by margin descending.
```

Vary the prompts so the set covers more than the happy path:

- Mix formal and casual phrasing.
- Mix explicit intent (states the file type) with implicit (must be inferred from context).
- Mix simple and multi-step tasks.
- Start with two or three: one core case, one edge case, optionally one composite.

## 3. With-skill vs baseline

To confirm a skill actually adds value, run the same prompt twice in parallel — once with the
skill, once without — and compare:

- **With-skill:** the agent reads the skill and does the work.
- **Baseline:** the same prompt, no skill. When improving an *existing* skill, the baseline is
  the previous version (keep a snapshot), not an empty run.

Keep each run's outputs in their own directory so iterations don't overwrite each other. If
you capture timing or token counts, save them from the completion notification immediately —
that data is available only at that moment and cannot be recovered later.

## 4. Assertion-based scoring

When the deliverable is objectively checkable, write assertions. A good assertion can be
judged true or false, has a descriptive name, and tests the skill's core value. A bad one is
subjective ("it reads well") or passes regardless of the skill ("output exists").

Watch for **non-discriminating** assertions — ones that pass in both the with-skill and the
baseline run. They measure nothing about the skill; drop them or replace them with a harder
one. Where an assertion can be checked by code, script it: faster, repeatable, and reusable
across iterations. Record results with the field names `text`, `passed`, `evidence` (the same
schema the setup-side skill-writing guide defines).

## 5. Trigger validation

A skill's description is its only trigger. Validate it with two query sets:

- **Should-trigger (8–10):** the same need phrased many ways — formal and casual, explicit and
  implicit, including cases where this skill should win over a competing one.
- **Should-NOT-trigger (8–10):** **near-misses are the point.** A query with overlapping
  keywords but where a *different* tool is the right fit tests the boundary; an obviously
  unrelated query ("write a Fibonacci function") tests nothing. Build the should-NOT set from
  queries that belong to adjacent skills — especially, for this plugin's own two skills, a
  "review my harness" that must not fire `harness-setup` and an "extend my harness" that must
  not fire `harness-review`. Include near-misses from *external* neighbours too: "recommend
  Claude Code automations for this repo" (belongs to `claude-code-setup`), "write a skill or
  plugin for X" (`plugin-dev` / `skill-creator`), and "review this PR / this code" (code
  review) — none of these should fire either harness skill.

Then check for collisions: confirm the should-trigger queries don't wrongly fire a *different*
existing skill. Where two descriptions overlap, sharpen the boundary wording in both.

## 6. The improvement loop

When a test surfaces a problem:

1. **Generalize the fix.** Repair the principle, not the one example that failed — a narrow
   patch that fits only the test case is overfitting.
2. **Cut what doesn't earn its place.** If the transcript shows the skill making the agent do
   unproductive work, remove that part.
3. **Explain the why.** Even terse feedback has a reason behind it; fold the reason into the
   skill so it generalizes.
4. **Bundle repetition.** If every run writes the same helper, pre-bundle it under `scripts/`.

Re-run all cases in a fresh iteration directory, show the user the result against the previous
one, and repeat. Stop when the user is satisfied, when feedback comes back empty, or when
there is no more meaningful improvement to make. Draft, then re-read with fresh eyes — don't
expect the first pass to be the final one.
