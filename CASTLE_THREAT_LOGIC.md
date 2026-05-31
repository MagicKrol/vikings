# Castle Threat Logic (Current Runtime Behavior)

## Purpose
This document describes how castle threats are detected and handled by AI in current code.
It covers:
- actors and responsibilities,
- threat states and transitions,
- per-army threat response behavior,
- recruitment behavior while threatened,
- concrete gameplay scenarios.

## Actors
- `EconomyAIManager.gd`
	- Detects and classifies castle threats.
	- Builds pre-move threat snapshot for `TurnController`.
	- Recalculates threat and executes castle recruitment post-move.
- `TurnController.gd`
	- Uses snapshot to decide army behavior (attack/merge/sortie/reposition/hold).
- `ArmyManager.gd`
	- Maintains `castle_nearby_entities` cache used as input for threat scanning.
- `GameManager.gd`
	- Runs threat battle simulations used for known-threat classification.
- `RecruitmentManager.gd`
	- Executes garrison hiring with reserved budget.
- `PlayerManagerNode.gd`
	- Provides tracked enemy power ("known" vs "unknown").

## Detection Range (What means "castle threatened")
Castle threat source candidates come from `castle_nearby_entities["enemy_army_ids"]`.

This cache is built from `Region.nearby_regions`, which is computed at map generation with BFS depth `2` over non-ocean adjacency.

Then each candidate is filtered by one-turn reachability:
- threat is accepted only if path to castle exists and movement cost is `<= GameParameters.MOVEMENT_POINTS_PER_TURN`.

So practical detection is:
- in nearby cache radius (up to 2 steps), and
- actually reachable in one turn by pathfinder.

## Threat States
Internal labels and levels:
- `castle_safe` => level `1` (value `1`)
- `needs_army` => level `2` (value `2`)
- `unknown` => level `3` (value `2`)
- `big` => level `4` (value `4`)
- no threat => level `0`

### Known Threat Classification
Known threats are grouped by enemy region and simulated:
- `castle_only_sim`: attacker vs defenders without local defender army.
- `with_army_sim`: attacker vs defenders with local defender army.

Result mapping:
- attacker wins `with_army_sim` => `big` (level 4)
- attacker loses `with_army_sim` but wins `castle_only_sim` => `needs_army` (level 2)
- attacker loses `castle_only_sim` => `castle_safe` (level 1)

### Unknown Threat Classification
If tracked enemy power is missing, threat is `unknown` (level 3), no power comparison available.

## Turn Timing
1. **Pre-move economy phase**
- build threat snapshot (`threat_levels_by_region`, `threat_registry_by_region`)
- build reserved recruitment budgets for threatened castles.

2. **Army action phase**
- each army processes threat behavior using snapshot.
- if AI captures a region during movement (`battle_victory`, or defender-side withdrawal conquest), TurnController refreshes the in-turn snapshot immediately.

3. **Post-move economy phase**
- refresh threat after movement,
- recalc castle reserve budgets,
- execute castle recruitment (`hire_garrison`).

## Threat Response Order (per army)
When army enters threat cycle:
1. direct attack attempt
2. local same-region merge + attack attempt
3. support merge attempt
4. garrison sortie attempt
5. reposition to threatened castle fallback

If none applies, army continues to non-threat pipeline.

## Direct Attack Rules
### Non-castle target
- known threat: attack only if `army_power > known_power`.
- unknown grouped threat: direct attack allowed by grouped unknown branch.

### Castle target
- known threat: must pass castle simulation policy (`_evaluate_merge_policy` => `proceed`).
- unknown threat: blocked for normal direct attack path.
- exception: garrison sortie can call viability with `allow_unknown_castle = true`.

## Garrison Sortie Rules
Sortie applies only when acting army is inside own castle.

Known threat:
- must pass power-ratio pull-plan gate:
	- minimum required power `>= 120%` of enemy power,
	- desired cap `<= 150%` of enemy power,
	- garrison can be pulled proportionally to meet target.

Unknown threat:
- no ratio-based pull-plan requirement,
- sortie can still proceed through the unknown-allowed viability path.

Multi-threat castle (`active_threat_count > 1`):
- sortie requires same-turn attack + return MP feasibility,
- if feasible and attack succeeds, army returns to castle.

## Reposition-to-Defend Rules
For armies not already in target castle:

Evaluate castle defense need:
- `known_needs_more_defenders = known_enemy_power_total > current_defense_power`
- `unknown_needs_defender = has_unknown_threat AND current_defense_power < unknown_floor AND no_friendly_army_in_castle AND not_marked_defended`

If either need is true and castle is reachable this turn, army repositions to castle, requests recruitment, and camps.

## Unknown Threat Defense Floor
Unknown threat uses a minimum defense floor based on minimal recruitment-threshold formula:

`floor = ceil(10 * (1 + 0.03 * min(turn, 40)) * peasant_power * 2)`

Usage:
- hold/reposition under unknown threat is required only when defense is below this floor.
- if defense meets floor, unknown-threat hold can be released.

## Hold-in-Castle Behavior
If army is in own castle and threat remains:
- level 1 (`castle_safe`): release (no forced hold).
- level 2 (`needs_army`): hold/camp unless direct attack is executable.
- level 3 (`unknown`): hold/camp unless defense `>= unknown_floor` (then release).
- level 4 (`big`): this hold branch does not force camp; army uses main threat-action path.

Also, if multiple friendly armies are already in castle, hold branch does not force additional hold on that army.

## Recruitment Behavior While Threatened
There are two recruitment paths:

1. **Army-local recruitment (during army loop)**
- if army is in threatened own castle, recruitment logic can recruit at current region (`recruit_hold_threatened_castle`).

2. **Castle defense recruitment (post-move)**
- pre-move garrison defense hires are deferred,
- after army movement, threatened castles receive reserved budgets,
- garrison hiring executes in post-move phase.

So yes: castle can continue to hire while an army is stationed there because of threat.

## Scenario Reference
### Scenario A: Known threat, castle weaker
Condition:
- known enemy total power > current castle defense power.
Outcome:
- army tries attack/merge/sortie chain first.
- if no viable attack and reachable defender exists, reposition to castle.
- post-move garrison recruitment runs.

### Scenario B: Known threat, castle equal/stronger
Condition:
- known enemy total power <= current castle defense power.
Outcome:
- no forced defender reposition from known-gap rule.
- army may continue with normal role behavior if not otherwise locked.

### Scenario C: Unknown threat, castle below unknown floor
Condition:
- unknown threat exists and castle defense < unknown floor.
Outcome:
- keep one defender logic active,
- hold/reposition may keep army in castle,
- recruitment continues to raise defense.

### Scenario D: Unknown threat, castle at/above unknown floor
Condition:
- unknown threat exists and castle defense >= unknown floor.
Outcome:
- unknown-hold release branch allows army to stop hard-camping,
- army can proceed to other actions.

### Scenario E: Unknown threat, sortie opportunity
Condition:
- army in threatened castle with reachable threat region.
Outcome:
- garrison sortie can trigger even when threat is unknown,
- for multi-threat castles, must be able to attack and return in same turn.
