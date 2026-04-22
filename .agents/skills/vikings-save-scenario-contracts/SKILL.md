---
name: vikings-save-scenario-contracts
description: Save/load/scenario schema and persistence contract for this Godot 4.3 project. Use when changing save_game_manager.gd, scenario_manager.gd, map_editor_panel.gd, main_menu_save_game_modal.gd, save_game_modal.gd, scenarios/*.json, or PROJECT_MAP.MD, or when adjusting save/load payloads, scenario fields, compatibility, or migration behavior.
---

# Vikings Save Scenario Contracts

Use this skill when changing runtime persistence, scenario JSON, or any data that must survive save/load.

## Workflow

1. Inspect the current save and scenario shapes before editing.
2. Update the smallest set of fields needed.
3. Keep existing keys working unless the user explicitly asked for a breaking change.
4. Mirror any schema change in `PROJECT_MAP.MD`.
5. Verify the game still parses and loads the updated data.

## Contract Checklist

- Preserve backward compatibility for existing save files and scenarios.
- Do not rename or remove keys unless the change is requested and migration is handled.
- Keep scenario JSON and runtime serialization aligned.
- Keep editor, main-menu, and in-game save flows consistent.
- Update `PROJECT_MAP.MD` when save/scenario responsibilities or payload fields change.
- Avoid introducing fallback behavior that changes game logic unless requested.
- Keep schema changes local to the requested task.

## Files To Check

- `save_game_manager.gd`
- `scenario_manager.gd`
- `map_editor_panel.gd`
- `main_menu_save_game_modal.gd`
- `save_game_modal.gd`
- `scenarios/*.json`
- `PROJECT_MAP.MD`
- other manager files.

## Validation

Run:

```bash
godot4 --headless --check-only --path . project.godot --quit
```
