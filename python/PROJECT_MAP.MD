# PROJECT_MAP

- battle_tester.py: Tkinter battle simulator mirroring Godot combat; key functions simulate_battle, process_unit_attacks, simulate_battle_series; BattleApp UI for configuring armies, seeds, grassland, assault/defense modifiers (with defense mod exponent), running repeats with saved battle snapshots, and resetting New Battle back to the last saved Repeat setup.
- fix_scenario_gold_ranges.py: Scenario maintenance utility that reports positive Hills/Forest Hills Gold ranges against `GameParameters.REGION_RESOURCES`, leaves zero/no-ore Gold untouched, supports filename excludes, shows example proportional fixes, and only writes scenario JSON when run with `--apply`.
