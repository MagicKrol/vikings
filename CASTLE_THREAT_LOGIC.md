# Castle Threat Logic (Current Runtime Behavior)

## Purpose
This document describes how AI reacts to threatened owned castles.

Scope:
- threat detection and snapshot building in `EconomyAIManager.gd`,
- threatened-castle behavior in `TurnController.gd`,
- recruitment behavior while a castle is threatened.

Normal non-castle frontier logic is outside this document and is not changed by the home-castle threat branch.

## Actors
- `EconomyAIManager.gd`
	- Detects and classifies castle threats.
	- Builds the pre-move threat snapshot for `TurnController`.
	- Recalculates threat and executes castle recruitment post-move.
- `TurnController.gd`
	- Decides whether an army inside its own threatened castle should recruit, attack, return, hold, leave a minimal garrison, or release to normal target scoring.
- `ArmyManager.gd`
	- Maintains `castle_nearby_entities` cache used as threat-scanning input.
- `GameManager.gd`
	- Runs battle and siege simulations used for known-threat decisions.
- `RecruitmentManager.gd`
	- Executes garrison hiring with reserved castle-defense budgets.
- `PlayerManagerNode.gd`
	- Provides tracked enemy power. Missing tracked power means unknown threat.

## Detection Range
Castle threat source candidates come from `castle_nearby_entities["enemy_army_ids"]`.

This cache is built from `Region.nearby_regions`, which is computed at map generation with BFS depth `2` over non-ocean adjacency.

Each candidate is then filtered by one-turn reachability:
- threat is accepted only if a path to the castle exists,
- movement cost must be `<= GameParameters.MOVEMENT_POINTS_PER_TURN`.

## Threat States
Internal labels and levels:
- `castle_safe` => level `1`
- `needs_army` => level `2`
- `unknown` => level `3`
- `big` => level `4`
- no threat => level `0`

Known threats are grouped by enemy region and simulated:
- `castle_only_sim`: attacker vs castle defenders without the local defender army.
- `with_army_sim`: attacker vs castle defenders with the local defender army.

Result mapping:
- attacker wins `with_army_sim` => `big` (level 4)
- attacker loses `with_army_sim` but wins `castle_only_sim` => `needs_army` (level 2)
- attacker loses `castle_only_sim` => `castle_safe` (level 1)

If tracked enemy power is missing, the threat is `unknown` (level 3).

## Turn Timing
1. Pre-move economy phase:
	- build threat snapshot,
	- build reserved recruitment budgets for threatened castles.
2. Army action phase:
	- armies process movement using the snapshot,
	- in-turn AI conquest refreshes the threat snapshot immediately.
3. Post-move economy phase:
	- refresh threat after movement,
	- recalculate castle reserve budgets,
	- execute castle garrison recruitment.

## Under-Strength Armies
Before threatened-castle logic, an army inside its own threatened castle checks the minimal recruitment threshold:

`army.needs_recruitment(turn_number, false, true, false)`

If true:
- the army requests recruitment,
- it runs the existing recruitment routing first,
- local threat-locked camping recruitment is bypassed for this pass so the army can seek the best recruitment castle.

This covers token armies such as a one-peasant stack without re-enabling the commented peasant-specific cycle.

## Home-Castle Threat Context
When an army is inside its own threatened castle, `TurnController` builds grouped threat contexts by enemy region.

Each context preserves:
- threat region id,
- source threat entries,
- known total power,
- whether any source is unknown,
- whether the target region has a castle,
- attack path and cost,
- return path and cost,
- same-turn attack feasibility,
- same-turn attack-and-return feasibility.

If a group has any unknown source, the whole group is treated as unknown-risk. Known power in that same group is not used alone to green-light an attack.

## Attack Thresholds
Known-power attacks require at least `120%` of the known threat power:

`required_power = ceil(enemy_power * 1.2)`

Home-castle known attacks pull only the minimum garrison needed to pass `120%`; `150%` remains the hard upper cap. For multi-threat no-return attacks, the remaining castle defense must still be safe after any garrison pull. The older non-home sortie path keeps its existing proportional pull behavior.

Unknown non-castle threats can be attacked only when the army can also return to the home castle in the same turn. Unknown castle targets are not attacked by this branch.

## Home-Castle Decision Tree
### Single Unknown Threat
- If the threat is reachable and attack-and-return is possible, attack and return.
- Otherwise hold, request recruitment, and camp.
- If the same unresolved threat causes a second consecutive hold, leave only a minimal safe garrison and release to normal target scoring when the castle remains defensible.

### Single Known Threat
- If castle-only defense can hold, release the army to normal target scoring.
- If the castle cannot hold and the army can attack at `>= 120%`, attack.
- If the army needs garrison help, pull from garrison to meet the attack gate.
- If no safe attack or release exists, hold, request recruitment, and camp.

### Multiple All-Unknown Threats
- Try the closest attackable unknown threat only when attack-and-return is possible.
- Otherwise hold, request recruitment, and camp.
- If the same unresolved threat set causes a second consecutive hold, release only when a minimal garrison keeps the castle safe.

### Multiple Mixed Known/Unknown Threats
- Unknown-risk groups are not reduced to their known power only.
- First try a known weaker non-unknown group at `>= 120%`.
- The known attack can skip return only when the remaining castle defense is safe after the attacked threat is excluded.
- Otherwise try the closest unknown-risk non-castle group only with attack-and-return.
- If no safe action exists, hold/recruit, with second-turn release only when minimal garrison keeps the castle safe.

### Multiple All-Known Threats
- Try known weaker targets at `>= 120%`.
- Attack-and-return is preferred.
- No-return attack is allowed only when the remaining castle defense is safe.
- If needed, the army can transfer a minimal garrison first, spend 1 MP, and attack only if the remaining army still meets the known attack gate.
- If castle-only defense can hold against all threats, release the army to normal target scoring.
- If no safe attack or release exists, hold, request recruitment, and camp.

### Big Threats
Level 4 threats are no longer auto-released by castle-hold logic.

The army holds/recruits unless:
- a verified safe attack exists,
- or the live threat set no longer requires the army because the castle can defend itself or can be made safe with a minimal garrison.

### Castle-vs-Castle Standoff
If an enemy castle is treated as a threat but direct assault is blocked by siege simulation or unknown castle power:
- do not camp forever when the home castle is already safe,
- release to normal target scoring when castle-only defense is safe,
- or transfer a minimal safe garrison and release when MP remains,
- otherwise hold/recruit.

## Minimal Garrison Transfer
Minimal garrison transfer is army-to-garrison and costs `1` MP.

It is allowed only when:
- the castle defense after transfer can cover all non-attacked threat contexts,
- the acting army remains at or above the minimal recruitment threshold after the transfer,
- and, when attacking, the acting army also remains at `>= 120%` of the selected known target.

Defense power for this check includes:
- current garrison,
- base available recruits as peasant-power reserve,
- other friendly armies in the castle,
- not the acting army.

Unknown-risk defense uses the unknown threat floor:

`ceil(10 * (1 + 0.03 * min(turn, 40)) * peasant_power * 2)`

## Hold Behavior
Holding a home castle:
- requests army recruitment,
- spends remaining MP camping,
- remembers the live threat signature for the next turn.

If the same signature repeats, the army may release only if the castle can remain safe without the full army.

## Recruitment While Threatened
Two recruitment paths exist:

1. Army-local recruitment:
	- under-strength threatened-castle armies route to recruitment before threat handling,
	- normal threat holds request recruitment while camping.
2. Castle defense recruitment:
	- threatened castles receive reserved budgets,
	- garrison hiring executes in the post-move economy phase.

## Scenario Reference
### Known Threat, Castle Weaker
The army attacks at `>= 120%`, pulls garrison if needed, or holds/recruits if no safe attack exists.

### Known Threat, Castle Safe
The army is released to normal target scoring instead of camping in a castle that can defend itself.

### Unknown Threat, Reachable With Return
The army attacks the unknown non-castle threat and returns to the home castle in the same turn if it survives.

### Unknown Threat, No Return
The army holds/recruits once. On repeated same-threat hold, it may leave a minimal garrison and resume normal target scoring if the castle remains safe.

### Multiple Threats, Strong Castle Army
The army can leave a minimal garrison and attack a selected known weaker target when:
- it has enough MP for transfer plus attack,
- the remaining garrison can defend the other threats,
- the remaining army still meets the minimal recruitment threshold and the `120%` attack gate.

### Mixed Known and Unknown Threats
Known-only groups may be attacked using the `120%` gate. Mixed groups remain unknown-risk and require attack-and-return if attacked as unknown.

### Enemy Castle Standoff
If the enemy castle cannot be safely assaulted, the AI releases to normal target scoring only when the home castle is safe or can be made safe with a minimal garrison.

### Below-Minimal Army in Threatened Castle
The army requests recruitment and runs recruitment routing before threatened-castle decisions. The peasant-specific cycle remains commented out.
