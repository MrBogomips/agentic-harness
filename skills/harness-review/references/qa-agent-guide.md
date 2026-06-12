# QA agent guide

What a good QA agent does, so you can assess one in an existing harness or specify one for
`harness-setup` to build. The method is drawn from common boundary-bug patterns — recurring
failure modes that surface where two correctly-built components meet.

## Table of contents

1. [The bugs QA agents miss](#1-the-bugs-qa-agents-miss)
2. [Why static checks don't catch them](#2-why-static-checks-dont-catch-them)
3. [Cross-boundary verification](#3-cross-boundary-verification)
4. [Design principles](#4-design-principles)
5. [Integration-consistency checklist](#5-integration-consistency-checklist)
6. [QA agent definition template](#6-qa-agent-definition-template)

---

## 1. The bugs QA agents miss

The most common defect is a **boundary mismatch**: two components are each correct on their
own, but the contract between them is broken at the seam. Each passes its own review; nobody
compares the two sides. Recurring forms:

| Boundary | Mismatch | Why it's missed |
|----------|----------|-----------------|
| response → consumer type | the producer returns `{ items: [...] }`; the consumer expects a bare array | each is fine alone; no one compares the shapes |
| field name across layers | one layer uses camelCase, another snake_case for the same field | a generic cast hides it from the compiler |
| route path → link target | a page lives under one path prefix; a link points at another | file layout and link values aren't cross-checked |
| state map → update sites | the transition map allows a move the code never performs (or vice versa) | only the map's existence is confirmed, not every update site |
| endpoint → caller | an endpoint exists but nothing calls it (or a caller hits a missing one) | the endpoint list and caller list aren't mapped 1:1 |
| immediate vs async result | the immediate response lacks a field the consumer reads off it | only the type is checked, not sync vs async timing |

## 2. Why static checks don't catch them

- **Generic casts defeat the type checker.** A typed fetch annotated to return one shape will
  compile even when the runtime value has another — the annotation is a claim, not a check.
- **A passing build is not correct behavior.** With casts, `any`, or generics in play, the
  build succeeds and the code still fails at runtime.
- **Existence is not connection.** "Does the endpoint exist?" and "does its response match
  what the caller expects?" are different questions; only the second catches boundary bugs.

## 3. Cross-boundary verification

The core technique: compare the two sides of a contract directly, never one in isolation.

- **Response shape ↔ consumer type.** Extract the shape the producer actually returns and the
  type the consumer expects, and compare — including any wrapper (does the producer return
  `{ data: [...] }` while the consumer reads a bare array?), and field-name casing across
  layers, and the difference between an immediate acknowledgement and the eventual result.
- **Route path ↔ link target.** Derive each page's real path from the file layout and compare
  it against every link, redirect, and navigation target in the code; account for path
  prefixes and dynamic segments.
- **State map ↔ update sites.** List the transitions the map allows, then find every place the
  code changes state; flag transitions the code performs that the map forbids, and transitions
  the map allows that the code never performs.
- **Endpoint ↔ caller.** List every endpoint and every call site and pair them; an endpoint no
  one calls is either dead or a missing wire-up — decide which.

## 4. Design principles

- **Use the `general-purpose` type, not `Explore`.** Effective QA greps for patterns, runs
  comparison scripts, and sometimes fixes — `Explore` is read-only and can't. Give the agent a
  "verify → report → request fix" protocol instead of read-only tooling.
- **Prefer cross-boundary comparison over existence checks.** "Does the response shape match
  the consumer's type?" beats "does the endpoint exist?"; "does every update obey the state
  map?" beats "is the map defined?".
- **Read both sides at once.** To catch a seam bug, open the producer and the consumer
  together — the route and its caller, the state map and the update code, the file layout and
  the links. State this explicitly in the agent definition.
- **Run incrementally, not just at the end.** QA placed only after everything is built lets
  early mismatches propagate and raises the cost of every fix. Verify each module's boundaries
  as it lands.

## 5. Integration-consistency checklist

A template to fold into a QA agent for a typical web application:

```markdown
### Integration consistency

#### Response ↔ consumer
- [ ] Every response shape matches the consumer's expected type
- [ ] Wrapped responses ({ items: [...] }) are unwrapped on the consumer side
- [ ] camelCase/snake_case is consistent across layers
- [ ] Immediate acknowledgements and eventual results are distinguished on the consumer
- [ ] Every endpoint has a caller, and every caller hits a real endpoint

#### Routing
- [ ] Every link / redirect / navigation target resolves to a real page path
- [ ] Path prefixes and route groups are accounted for
- [ ] Dynamic segments are filled with the right parameters

#### State machine
- [ ] Every transition the code performs is allowed by the map (no unauthorized moves)
- [ ] Every transition the map allows is reachable in the code (no dead transitions)
- [ ] Intermediate-to-final transitions are present, not missing
- [ ] State-based branches on the consumer are actually reachable

#### Data flow
- [ ] Field names match from storage through response to consumer type
- [ ] Optional-field null/undefined handling is consistent on both sides
```

## 6. QA agent definition template

```markdown
---
name: qa-inspector
description: "QA verification specialist. Checks spec compliance, integration consistency, and design quality across module boundaries."
model: inherit
---

# QA inspector

## Core role
Verify implementation quality against the spec, and **integration consistency between
modules** — boundary mismatch is the leading cause of runtime failure.

## Verification priority
1. Integration consistency (highest)
2. Functional spec compliance
3. Design quality
4. Code quality (dead code, naming)

## Method: read both sides at once
| Target | Producer side | Consumer side |
|--------|---------------|---------------|
| response shape | where the response is built | where it is consumed and typed |
| routing | page path from the file layout | link / redirect / navigation target |
| state | the transition map | the state-update sites |
| data | storage field names | response field → consumer type |

## Team communication protocol
- On a finding, send a specific fix request (location + fix) to the responsible agent.
- For a boundary issue, notify **both** sides.
- To the leader: a report separating passed / failed / unverified.
```
