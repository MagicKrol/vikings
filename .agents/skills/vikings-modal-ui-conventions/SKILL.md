---
name: vikings-modal-ui-conventions
description: Modal and UI scene updates for this Godot 4.3 project. Use when changing modal layouts, button behavior, interaction blocking, click handling, or scene/script wiring in `ui_manager.gd`, `click_manager.gd`, `main.tscn`, or `scenes/*_modal.*`.
---

# Vikings Modal UI Conventions

Use this skill when editing modal scenes, UI manager logic, or click handling.

## Workflow

1. Change static UI values in `.tscn` scenes, not in `_ready()`, unless the value must be dynamic at runtime.
2. Keep modal behavior local to the related modal script and scene.
3. Preserve existing interaction blocking rules in `ui_manager.gd` and `click_manager.gd`.
4. Avoid changing unrelated modal flows, button order, focus handling, or tooltip behavior.
5. Update the matching scene and script together when a modal needs structural changes.
6. Keep `PROJECT_MAP.MD` aligned with any scene or script role changes.

## Scope

- `ui_manager.gd`
- `click_manager.gd`
- `main.tscn`
- `scenes/*.tscn` modal scenes
- corresponding `*_modal.gd` files
- `PROJECT_MAP.MD`

## Constraints

- Do not move static scene defaults into script initialization.
- Do not add extra modal logic unless it is directly requested.
- Keep UI changes minimal and consistent with the existing modal architecture.

## Validation

Run:

```bash
godot4 --headless --check-only --path . project.godot --quit
```
