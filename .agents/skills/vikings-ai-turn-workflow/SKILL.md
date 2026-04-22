---
name: vikings-ai-turn-workflow
description: Safe workflow for AI turn logic changes in this project. Use when editing AI economy, target scoring, recruitment routing, movement decisions, or AI logging across TurnController and related managers.
---

# Vikings AI Turn Workflow

Use this workflow for AI behavior updates.

## Scope Files First

- `TurnController.gd`
- `EconomyAIManager.gd`
- `ArmyTargetScorer.gd`
- `RecruitmentManager.gd`
- `BudgetManager.gd`
- `AILogManager.gd`
- `AI_BEHAVIOUR.md`
- `PROJECT_MAP.MD`

## Change Workflow

1. Identify one decision point to change (do not batch unrelated AI rewrites).
2. Trace call flow from `TurnController` into scoring/economy/recruitment before editing.
3. Change only the minimum logic required for the request.
4. Keep deterministic behavior where already deterministic (ordering, allocation, logging shape).
5. Do not retune unrelated balancing constants in `GameParameters.gd` unless requested.
6. Update `AI_BEHAVIOUR.md` and `PROJECT_MAP.MD` for behavior changes.

## Validation

Run compile check:

```bash
godot4 --headless --check-only --path . project.godot --quit
```

Run targeted tests when the touched subsystem has coverage:

```bash
godot4 --headless --path . -s tests/cli_test_runner.gd
```
