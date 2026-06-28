# AI Behaviour Documentation (Current Implementation)

This document describes the current AI decision logic for:
- raising armies
- building and upgrading castles
- promoting regions
- selecting targets and moving armies

It is based on these files:
- `TurnController.gd`
- `EconomyAIManager.gd`
- `ArmyTargetScorer.gd`
- `ArmyPathfinder.gd`
- `region_manager.gd`
- `game_manager.gd`
- `ai/RaiseArmyDecision.gd`
- `GameParameters.gd`

## 1. AI Turn Order (High Level)

For each AI player turn (`TurnController.start_turn`):

1. Economy planning (`EconomyAIManager.plan_turn`)
2. Army action loop (`_process_army_turns`)
3. Resource top-up trade pass (`_execute_ai_resource_top_up`)
4. Wealth level refresh (`PlayerManagerNode.update_player_wealth_status`)

Economy planning runs in this fixed order:

1. Army recruitment budgets + castle defense recruitment
2. Raise new army decision
3. Build castle
4. Upgrade castle
5. Repair damaged castles

AI gold income uses a difficulty bonus when income is applied: Easy +0%, Normal +5%, Hard +15%.
6. Promote regions
7. Ore search
8. Additional garrison trickle recruitment
9. Trade (sell surplus, buy food for deficit)

Scarce army recruitment is prioritized before pre-move army hires execute. If two or more castle armies are waiting, the AI simulates current recruitment budgets and repeatedly defers the army with the largest projected shortfall until the remaining armies can reach the minimal recruitment threshold, or only one army remains. The final single army always keeps its budget even if it cannot reach minimum. Deferred armies keep their recruitment request and try again next turn. Castle/garrison defense budgets are not changed by this pruning.

## 2. Economy Logic (Promoting / Building / Upgrading / Raising)

### 2.1 Raise Army

Flow:

1. Find eligible owned castle regions (`pick_best_raise_region`)
2. Candidate must have:
	- castle level >= 2
	- region not at army cap
	- recruits from castle + owned neighbors >= difficulty threshold
		- Easy: 40
		- Normal: 30 when no severe castle threat, otherwise 40
		- Hard: 25 when no severe castle threat, otherwise 40
3. If a friendly army in the selected raise castle already has a recruitment request, skip raising there so the castle can recruit that army instead.
4. Candidate score:
	- `score = 40 * recruits_norm + 30 * frontier_near + 20 * travel_hint`
5. Choose highest score (tie: lower region id)
6. Run `should_raise_army` using `RaiseArmyDecision`

The AI raise reserve can start saving before the recruit threshold is met. If the player already has an army but owns any non-full level 2+ castle, the reserve bank may lock gold for a future raise; the actual raise still requires a full candidate with enough recruits. While this future source exists, `Raise Army` reports `waiting_for_recruits` instead of releasing the saved raise reserve.

Hard gates in `RaiseArmyDecision.score`:

- `gold_after_raise >= reserve threshold`
	- Easy: 30
	- Normal: 20 when no severe castle threat, otherwise 30
	- Hard: 0 when no severe castle threat, otherwise 30
- `recruits >= recruit threshold`
- `frontier_regions / armies >= AI_RAISE_FRONTIER` (2.5)

Normalized raise score:

- `r2a_norm = norm(regions/armies, 3.0..5.0)`
- `dist_norm = norm(avg_dist_mp, 2.0..10.0)`
- `recruits_norm = norm(recruits, effective_recruit_threshold..200)`
- `bank_norm = norm(gold_after_raise, effective_reserve_threshold..200)`

Final raise score:

- `0.50*r2a_norm + 0.20*dist_norm + 0.20*recruits_norm + 0.10*bank_norm`

Decision:

- raise if score >= difficulty threshold
	- Easy: 0.50
	- Normal: 0.45 when no severe castle threat, otherwise 0.50
	- Hard: 0.40 when no severe castle threat, otherwise 0.50
- on execute: spend `RAISE_ARMY_COST` (20 gold), create army with `just_raised=true`
- on Normal/Hard, immediately assigns a small local recruitment budget to the raised army and hires toward the minimal recruitment power threshold; if the budget is insufficient, the army keeps a recruitment request for the next turn.

### 2.2 Build Castle

Flow (`_evaluate_build_castle`):

1. Check Outpost affordability before scanning candidates:
	- must have enough spendable gold for the build cost
	- missing non-gold resources may be top-up candidates only when each shortfall is <= `SMALL_CASTLE_TOPUP_LIMIT`
	- estimated top-up spend must still leave enough gold for the build cost
2. Pick best candidate (`_pick_castle_build_candidate`)
3. Candidate must:
	- be owned
	- be allowed by `region.can_build_castle()`
	- not be in exclusion set:
		- any region already with castle
4. Candidate score:
	- `strategic_score = region.strategic_point_score * 10`
	- `neighbor_score`:
		- +15 for each owned neighbor
		- +5 for each neutral neighbor
		- -10 for each enemy neighbor
		- -45 if any neighboring region already has a castle
	- `total_score = strategic_score + neighbor_score`
5. Must pass:
	- `total_score >= CASTLE_SCORE_THRESHOLD` (100)
	- forward requirement:
		- candidate must be closer to at least one enemy castle than current friendly baseline
		- skipped for candidates below the score threshold
6. Cost = outpost build cost from `GameParameters`
7. If resources missing:
	- optional small top-up trade (`_attempt_small_castle_topup`)
	- only for missing non-gold resources <= `SMALL_CASTLE_TOPUP_LIMIT` (5 each)
8. If affordable, pay cost and start construction (`region.start_castle_construction(OUTPOST)`)

### 2.3 Upgrade Castle

Flow (`_evaluate_upgrade_castle`):

1. Build candidate list from owned castles that:
	- are not under construction
	- can still upgrade
2. For each candidate:
	- `recruits_total` from castle + owned neighbors
	- `distance` to nearest enemy castle
	- `recruit_score = (recruits_total / best_recruits) * 100`
	- `distance_score = (min_distance / distance) * 100` (or 100 when distance=0)
	- `total_score = (recruit_score + distance_score) * 0.5`
3. Pick highest total score
4. Use next castle tier cost (`GameParameters.get_castle_building_cost(next_type)`)
5. Same small top-up trade logic as build
6. Pay and start construction (`region.start_castle_construction(next_type)`)

### 2.4 Promote Region (Region Level Upgrade)

Flow (`_evaluate_upgrade_region`):

1. Build owned-region candidate list (only levels below L5)
2. Per-region score (`_score_region_for_upgrade`):
	- `castle_bonus = castle_level * 2`
	- `population_bonus = floor(population / 100)`
	- `neighbor_bonus = sum(castle_level of owned neighbors)`
	- `recruit_bonus`:
		- +2 if recruits empty
		- +1 if partial
		- -2 if full
	- `score = castle_bonus + population_bonus + neighbor_bonus + recruit_bonus - current_level_number`
3. Sort by score desc
4. For each candidate, require:
	- score > 0
	- has promotion cost
	- region exists
	- cooldown inactive
	- food safeguard pass:
		- projected food after upgrade and next-turn growth must be >= `AI_MIN_FOOD_AFTER_UPGRADE` (50)
	- promotion growth guardrails:
		- L2 -> L3 requires wood growth >= `AI_REGION_PROMOTION_MIN_RESOURCE_GROWTH` and food growth >= `AI_REGION_PROMOTION_MIN_RESOURCE_GROWTH`
		- L3 -> L4 requires stone growth >= `AI_REGION_PROMOTION_MIN_RESOURCE_GROWTH`
	- player can afford and can pay
5. On success:
	- set next region level
	- regenerate region resources
	- set promotion cooldown to 3 turns

### 2.5 Ore Search

Flow (`ore_checks`):

1. Iterate owned regions
2. Stop if gold < `ORE_SEARCH_COST` (10)
3. If `region.can_search_for_ore()`:
	- run search
	- pay 10 gold
	- track attempts/discoveries

### 2.6 Garrison Recruiting

Two layers:

1. Threat-based castle defense recruitment
	- castle considered threatened if enemy armies are within 2 steps
	- if garrison power below per-castle safe threshold, request budget
	- recruit via `RecruitmentManager.hire_garrison`

2. Trickle garrison reinforcement (`perform_garrison_trickle`)
	- skipped on turn 1
	- per owned castle:
		- base units by castle tier (`4/5/6/6`)
		- full amount if garrison power < average army power
		- half amount (ceil) if <= 1.25 * average army power
	- unit type sampled from ideal garrison weights (with wood/iron growth gates)

### 2.7 Economy Trades

`_execute_ai_trades`:

1. Sell surplus of wood/food/stone/iron when growth > 0 and amount above AI trade threshold
2. If net food growth < 0, buy enough food to cover deficit (`ceil(-food_growth)`)

Additional post-movement top-up in `TurnController`:

- buy toward stock targets:
	- wood: 30
	- stone: 30
	- iron: 10

## 3. Army Action Loop (Per Army)

Each movable army is processed in a loop while MP > 0 (`_process_single_army`):

1. Castle garrison release when the army starts in a quiet castle.
2. Under-strength threatened-castle recruitment gate.
3. Threatened-castle response.
4. Castle-hold response.
5. Recruitment cycle.
6. Wounded healing.
7. Role target selection (`MAIN` / `RAIDER` / `SUPPORT`).
8. Merge/halt/proceed policy.
9. Execute movement and battle.
10. Repeat until no MP or blocked.

If no valid action, army spends remaining MP on camping.

The peasants-only cycle remains intentionally commented out.

Role assignment keeps the existing slot thresholds, but `WAR` mode counts valid MAIN hard goals within MAIN routed-goal range instead of only hard frontier regions. A valid MAIN hard goal is a non-owned castle or enemy-army region that passes known-overmatch checks and has a safe routed path.

### 3.1 Threatened Owned Castles

If an army is inside its own threatened castle and is below the minimal recruitment threshold, it requests recruitment and runs recruitment routing before threatened-castle decisions. This prevents token armies from being trapped in castle-defense logic.

For home-castle threats, TurnController groups threats by enemy region and treats any group with unknown power as unknown-risk. Known attacks require `>= 120%` of known enemy power and pull only the minimum needed garrison, capped at `150%`. Unknown non-castle attacks require attack-and-return to the home castle in the same turn.

When a castle can defend itself, the army is released to normal role target scoring. When it cannot, the army attacks only if the attack is safe, or it holds/recruits. On repeated same-threat holds, it can leave a minimal safe garrison and resume normal target scoring if the castle remains defensible and the army remains at or above its minimal recruitment threshold.

## 4. How Targets Are Built and Scored

### 4.1 Frontier Set

`RegionManager.get_frontier_regions(player_id)` returns:

- all non-owned neighbors of owned regions (enemy or neutral)

### 4.2 Base Region Value (`ArmyTargetScorer`)

Per-region raw components:

- strategic: `region.get_strategic_point_score()` (0..10 expected)
- population component: `min(10, population/50)`
- level component: `region_level * 2` (L1..L5 -> 2..10)
- resource component: weighted resource sum
- score bonus: optional editor/scenario `score_bonus`, added directly to attack base score after normalization

Normalized score:

- `overall_0_1 = clamp((strategic + population + level + resource)/40, 0..1)`
- `base_score_0_100 = (overall_0_1 * 100) + score_bonus`

Resource component details:

- weights:
	- food 1.25, wood 1.0, stone 1.0, iron 1.25, gold 0.5
- Gold and Iron contribute only after that ore type is discovered in the region; undiscovered ore is treated as zero in AI scoring.
- low-income multiplier:
	- food gets x3 when net food change < 5
	- non-food gets x3 when income < 5
- high-stockpile penalty:
	- non-gold gets x0.5 when stockpile > 100

### 4.3 Final Move Score in TurnController

For each frontier target:

- path is found with friendly traversal (`find_path_to_target(..., friendly_only=true, allow_enemy_target=true)`)
- movement cost = path cost
- hard targets are non-owned regions with a castle or enemy army, including neutral castles/outposts

Score formula (`_get_sorted_frontier_moves`):

- `final_score = base_score + ownership_bonus + random_modifier + pursue_bonus + castle_bonus + neutral_core_bonus + neutral_cluster_bonus + neutral_border_bonus - distance_penalty + enemy_adjustment.delta`

Terms:

- `ownership_bonus = 5` if enemy-owned region else 0
- `random_modifier in [0, AI_RANDOM_SCORE_MODIFIER)` where max is 5
- `pursue_bonus = 5` when known enemy ratio condition passes
- `castle_bonus = 4 + castle_type_value` for non-owned castle regions
- `distance_penalty = mp_cost` for normal frontier scoring; raider scored targets use `mp_cost * AI_MAIN_GOAL_DISTANCE_COST_MULTIPLIER` (2.0)
- `neutral_core_bonus` applies only to neutral, non-castle, no-enemy-army targets:
	- distance to nearest owned castle in owned-region steps gives `5 * (4 - distance)` for distance 1..3
	- at least one owned neighbor gives a single `+3` bonus
- `neutral_cluster_bonus` applies only to neutral, non-castle, no-enemy-army targets:
	- capped BFS counts connected neutral soft regions, including the target, up to `AI_NEUTRAL_CLUSTER_SCAN_MAX`
	- bonus is `AI_NEUTRAL_CLUSTER_BONUS_PER_EXTRA_REGION` per connected extra region beyond the target, capped by `AI_NEUTRAL_CLUSTER_BONUS_MAX`
	- scenario JSON `disable_neutral_cluster_bonus=true` disables this bonus only; `neutral_core_bonus` and `neutral_border_bonus` still apply
	- cached during each frontier refresh and logged in candidate lines
- `neutral_border_bonus` applies only to neutral, non-castle, no-enemy-army targets:
	- counts owned neighboring regions
	- bonus is `AI_NEUTRAL_BORDER_BONUS_PER_OWNED_NEIGHBOR` per owned neighbor, capped by `AI_NEUTRAL_BORDER_BONUS_MAX`
	- favors compact expansion over thin one-region lines into deep neutral clusters
- `enemy_adjustment` from tracked enemy intel:
	- if combined known enemy power / own power >= 1.25 => `nullify=true`, score forced to 0
	- if ratio > 1.0 => penalty of `-ceil((ratio-1)/0.05)`
	- if ratio < 1.0 => bonus of `+floor((1-ratio)/0.05)` capped at +10

Reachability handling:

- if target reachable this turn (`mp_cost <= current_mp`), it is in primary pool
- if none reachable, far targets are ordered by:
	- lowest mp_cost first
	- final_score tie-break
- before normal hard/soft frontier targeting, `MAIN` armies try routed goal selection:
	- first search non-owned goals within a difficulty range: Easy 2 hops, Normal 3 hops, Hard 4 hops
	- if no ranged goal route is handled, select the normal hard/soft MAIN frontier objective and try the same routed movement
	- use normal passable pathing, not friendly-only pathing
	- reject paths through intermediate castles
	- reject intermediate known enemy armies unless AI power is at least 120% of known enemy power
	- reject intermediate unknown enemy armies only on Easy; Normal and Hard allow them
	- score MAIN ranged goals with MAIN-only tuning: +5 same-turn reachability, `path_cost * 2` distance penalty, +10 castle bonus, castle bonus x3 if the AI owns no castle, another x3 if the castle is winnable with full known defenders, and 2x pursuit bonus for known enemy armies that the MAIN can beat at 120%
	- attack the first non-owned step on the selected path, then continue while MP allows after each successful step
- on Normal and Hard, `RAIDER` armies standing next to an enemy castle with unknown tracked garrison power attack it before normal scored raiding, so the castle can be scouted through normal battle/intel recording
- for `MAIN` hard-target selection (`require_reachable_this_turn=true`), if no hard target is reachable now, AI advances toward the best unreachable hard target by score (higher `final_score`, then lower `mp_cost`) instead of camping in place

### 4.4 Known Enemy Gate Before Scoring

`ArmyTargetScorer.is_target_overmatched_by_known_enemy` can skip target completely when known intel indicates overmatch.

Core check uses:

- `GameManager.should_ai_withdraw_by_power(attacker_power, defender_power, assault_multiplier, defense_bonus, threshold)`
- withdraw condition:
	- `(attacker_power * assault_multiplier) / (defender_power * (1 + defense_bonus/100)) <= threshold`

Thresholds:

- castles: `AI_CASTLE_ATTACK_MIN_RATIO` = 1.5
- non-castles: `AI_FIELD_ATTACK_MIN_RATIO` = 1.0

For castles, assault multiplier uses `AI_CASTLE_ASSAULT_EXPECTED_MULTIPLIER` = 0.70.

## 5. Merge / Halt / Proceed Policy

After picking a candidate, `TurnController` builds enemy info and chooses:

- `proceed`
- `merge`
- `halt`

Rules (`_evaluate_merge_policy`):

1. If siege simulation result is `victory` -> proceed
2. If siege simulation result is `defeat` or `withdrawal` -> halt
3. If no enemy -> proceed
4. If enemy unknown -> merge
5. If own army power > known enemy power -> proceed
6. Else if local armies in same region combined power > enemy power -> merge
7. Else -> halt

After this policy, soft targets force `merge` back to `proceed`. Soft targets are regions with no castle and no enemy army, so ordinary expansion targets do not pull nearby armies together.

## 6. Movement Execution (Step-by-Step)

Movement is executed through `GameManager.ai_travel_to`.

1. Build full path from current region to selected target
2. For each step in path:
	- if MP <= 0 -> stop (`out_of_movement_points`)
	- if contested step (`_should_trigger_battle`) -> `perform_region_entry(..., "ai")`
	- else friendly move via `ArmyManager.move_army`
3. On contested step:
	- `battle_victory` -> continue path
	- `battle_withdrawal` -> stop and return withdrawal
	- `battle_defeat` -> stop and return defeat
	- `blocked` -> stop
4. At path end:
	- if final region reached -> `arrived` (or last battle result)
	- else `blocked`

Battle trigger (`_should_trigger_battle`):

- enemy-owned region
- or neutral region with defenders

## 7. Battle-Related AI Movement Decisions

Before starting AI castle battles:

1. Run simulated siege battle (`simulate_siege_battle`)
2. Try budgeted wood first, then uncapped-wood fallback
3. If final simulation is not victory, AI records the scouted defenders and withdraws before battle

Other withdrawal checks:

- pre-siege castle power check (`_should_ai_withdraw_pre_siege`)
- post-preparation power check (`_should_ai_withdraw_post_siege`) for non-castle path in current code
- in-battle siege no-assault check: if assault effectiveness is 0% and all active/reserve rams are gone, the AI attacker withdraws

If AI loses or withdraws and still has MP, TurnController retreats to strongest reachable friendly region within remaining MP.

## 8. Enemy Memory (Known vs Unknown)

AI uses tracked enemy memory in target and merge decisions.

- Enemy army and garrison power is stored per AI player
- Memory duration: `ENEMY_ARMY_MEMORY_ROUNDS = 5`
- Unknown enemy armies remain unknown until observed/tracked
- Known intel affects:
	- overmatch skip
	- pursuit bonus
	- score adjustment/nullification
	- merge/halt/proceed policy
- Raider unknown hard targets:
	- if hard target enemy strength is unknown, raider now rolls attack permission by difficulty:
		- Easy: 25%
		- Normal: 50%
		- Hard: 75%
	- failed roll rejects that candidate with `raider_unknown_hard_target`; successful roll allows regular move execution

## 9. Key Constants Used Most in Army Movement

- `MOVEMENT_POINTS_PER_TURN = 5`
- `ARMY_PATHFINDER_HORIZON_MP = 15` (3-turn planning horizon)
- `AI_RANDOM_SCORE_MODIFIER = 5`
- `AI_ENEMY_REGION_SCORE_BONUS = 5`
- `AI_PURSUIT_POWER_RATIO = 1.5`
- `AI_PURSUIT_SCORE_BONUS = 5`
- `AI_CASTLE_ATTACK_MIN_RATIO = 1.5`
- `AI_FIELD_ATTACK_MIN_RATIO = 1.0`
- `AI_CASTLE_ASSAULT_EXPECTED_MULTIPLIER = 0.70`

## 10. Summary: Action Decision Priority For One Army

In current implementation, each army effectively follows:

1. If below minimal recruitment threshold inside a threatened owned castle -> request recruitment and route to recruitment first
2. Else resolve threatened-castle actions, including attack-and-return, safe known attacks, minimal-garrison release, or hold/recruit
3. Else if needs core recruitment -> go to best friendly recruitment castle and recruit
4. Else pick best role/frontier target by score
5. If enemy unknown or stronger -> merge nearby armies if possible, except soft targets proceed without merging
6. If still unfavorable -> halt and camp
7. If favorable -> move step-by-step, fight when contested
8. After withdrawal/defeat -> retreat to strongest reachable friendly region
9. Burn remaining MP by camping
