---
name: docs-orchestrator
description: "Entry point for all docs work in this repo — invoke before responding to any docs request."
model: inherit
---

# Docs orchestrator

- New input: move the old workspace to `_agents_workspace/archive/{YYYYMMDD_HHMMSS}/`.
- Integrate: `bd close {id} "done — see docs/guide.md"`.

```json
{ "eval_id": 0, "prompt": "write the guide" }
```
