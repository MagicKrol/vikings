---
name: vikings-battle-pipeline
description: Battle and siege flow changes for Godot 4.3 combat, prebattle, battle modal, summary, siege UI, and GameManager finalization. Use when editing BattleManager.gd, BattleSimulator.gd, AnimatedBattleSimulator.gd, prebattle_modal.gd, battle_modal.gd, battle_summary_modal.gd, siege_panel.gd, game_manager.gd, or related combat flow documented in PROJECT_MAP.MD.
---

# Vikings Battle Pipeline

Use this skill when changing battle, siege, withdraw, finalization, or battle UI flow.

## Workflow

1. Read the current flow in `PROJECT_MAP.MD` before editing combat code.
2. Trace the change through `BattleManager.gd`, `BattleSimulator.gd`, `AnimatedBattleSimulator.gd`, and `game_manager.gd` before touching UI.
3. Keep `prebattle_modal.gd`, `battle_modal.gd`, `battle_summary_modal.gd`, and `siege_panel.gd` aligned with the simulator payload and battle result shape.
4. Preserve the existing asynchronous finalize path. Do not collapse deferred battle completion, camera pacing, or post-battle handoff into synchronous logic.
5. Keep changes minimal. Do not add new combat mechanics, siege rules, or fallback behaviors unless the user explicitly requests them.
6. Do not change unrelated balance constants, battle thresholds, or modal behavior outside the requested scope.
7. Keep combat state transitions explicit and single-purpose. Split helper logic when a function starts mixing simulation, UI, and finalization concerns.

## Edit Rules

- Change battle logic in the manager or simulator that owns it.
- Keep modal UI as presentation only.
- Keep scene defaults in `.tscn` when the change is static.
- Use typed GDScript and keep any new variables explicit.
- Avoid unrelated refactors in neighboring combat files.

## Validation

- Run: `godot4 --headless --check-only --path . project.godot --quit`
- If the change touches tests, run the relevant battle or siege test scene/script as well.
