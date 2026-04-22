---
name: vikings-guardrails
description: Enforce repository guardrails for this Godot 4.3 strategy project. Use when editing any game script/scene so changes stay minimal, typed, tab-indented, and aligned with AGENTS.md constraints.
---

# Vikings Guardrails

Apply these rules before writing code.

## Workflow

1. Read `AGENTS.md` and the relevant section of `PROJECT_MAP.MD`.
2. Limit edits to files directly required by the request.
3. Preserve existing mechanics and constants unless the request explicitly asks for balance/config changes.
4. Prefer the simplest implementation that solves the request.

## Mandatory Rules

- Use tabs for indentation in GDScript.
- Use explicit types for new variables and parameters.
- Use `get_node`, not `get_node_or_null`, for static project nodes.
- Do not add manager/node null checks for static scene nodes.
- Do not add fallback mechanics or extra game logic that was not requested.
- For static UI elements, change defaults in `.tscn`, not in `_ready`.
- Do not modify unrelated files or refactor outside the task scope.
- Keep `PROJECT_MAP.MD` current when scene/script behavior changes.

## Validation

Run and fix errors:

```bash
godot4 --headless --check-only --path . project.godot --quit
```
