#!/usr/bin/env python3
import tkinter as tk
from tkinter import ttk
import random
import math
from typing import Dict, List, Tuple, Optional

# =========================================
# Godot Enums (SoldierTypeEnum.gd)
# PEASANTS=0, SPEARMEN=1, SWORDSMEN=2, ARCHERS=3, CROSSBOWMEN=4,
# HORSEMEN=5, KNIGHTS=6, MOUNTED_KNIGHTS=7, ROYAL_GUARD=8
# =========================================
PEASANTS = 0
SPEARMEN = 1
SWORDSMEN = 2
ARCHERS = 3
CROSSBOWMEN = 4
HORSEMEN = 5
KNIGHTS = 6
MOUNTED_KNIGHTS = 7
ROYAL_GUARD = 8

# UnitTraitEnum.gd
LONG_SPEARS = 0      # UNIT_TRAIT_1
RANGED = 1           # UNIT_TRAIT_2
MOBILITY = 2         # UNIT_TRAIT_3
FLANKER = 3          # UNIT_TRAIT_4
CHARGE = 4           # UNIT_TRAIT_5
MULTI_ATTACK = 5     # UNIT_TRAIT_6
ARMOR_PIERCING = 6   # UNIT_TRAIT_7
SIEGE_LABORER = 7    # UNIT_TRAIT_8
BACK_RANK = 8        # UNIT_TRAIT_9
DEFENDER = 9         # UNIT_TRAIT_10

# =========================================
# Display order requested (screenshot order)
# =========================================
DISPLAY_ORDER = [
	PEASANTS,
	ARCHERS,
	SPEARMEN,
	SWORDSMEN,
	CROSSBOWMEN,
	HORSEMEN,
	KNIGHTS,
	MOUNTED_KNIGHTS,
	ROYAL_GUARD,
]

NAMES = {
	PEASANTS: "Peasants",
	SPEARMEN: "Spearmen",
	SWORDSMEN: "Swordsmen",
	ARCHERS: "Archers",
	CROSSBOWMEN: "Crossbowmen",
	HORSEMEN: "Horsemen",
	KNIGHTS: "Knights",
	MOUNTED_KNIGHTS: "Mounted Knights",
	ROYAL_GUARD: "Royal Guard",
}

# =========================================
# GameParameters.gd constants (combat-relevant)
# =========================================
CHARGE_BONUS_GRASSLAND = 1.0             # adds to multiplier (=> 2.0x total)
ARMOR_PIERCING_DEFENSE_REDUCTION = 0.5   # subtract from defense chance
LONG_SPEARS_CAVALRY_MULTIPLIER = 2.0
DEFENDER_ATTACK_MULTIPLIER = 2.0
MAX_ROUNDS = 1000

# =========================================
# UNIT_STATS copied from GameParameters.gd
# (attack/defense/traits plus power/cost for summaries)
# =========================================
UNIT_STATS = {
	PEASANTS: {
		"attack": 5,
		"defense": 8,
		"power": 2,
		"cost": 1,
		"traits": [SIEGE_LABORER],
	},
	SPEARMEN: {
		"attack": 8,
		"defense": 25,
		"power": 3,
		"cost": 2,
		"traits": [LONG_SPEARS, SIEGE_LABORER, DEFENDER],
	},
	SWORDSMEN: {
		"attack": 14,
		"defense": 35,
		"power": 4,
		"cost": 3,
		"traits": [SIEGE_LABORER],
	},
	ARCHERS: {
		"attack": 20,
		"defense": 15,
		"power": 4,
		"cost": 3,
		"traits": [RANGED, BACK_RANK],
	},
	CROSSBOWMEN: {
		"attack": 16,
		"defense": 20,
		"power": 4,
		"cost": 3,
		"traits": [RANGED, ARMOR_PIERCING, BACK_RANK],
	},
	HORSEMEN: {
		"attack": 15,
		"defense": 25,
		"power": 5,
		"cost": 4,
		"traits": [MOBILITY, FLANKER, CHARGE],
	},
	KNIGHTS: {
		"attack": 35,
		"defense": 70,
		"power": 10,
		"cost": 6,
		"traits": [],
	},
	MOUNTED_KNIGHTS: {
		"attack": 40,
		"defense": 70,
		"power": 12,
		"cost": 9,
		"traits": [FLANKER, CHARGE],
	},
	ROYAL_GUARD: {
		"attack": 40,
		"defense": 85,
		"power": 30,
		"cost": 12,
		"traits": [MULTI_ATTACK, ARMOR_PIERCING],
	},
}

# =========================================
# Helpers matching GameParameters / BattleSimulator
# =========================================
def unit_has_trait(unit_type: int, trait: int) -> bool:
	return trait in UNIT_STATS.get(unit_type, {}).get("traits", [])

def is_cavalry_unit(unit_type: int) -> bool:
	# GameParameters.is_cavalry_unit: mobility OR charge
	return unit_has_trait(unit_type, MOBILITY) or unit_has_trait(unit_type, CHARGE)

def army_size(army: Dict[int, int]) -> int:
	return sum(int(v) for v in army.values() if int(v) > 0)

def army_power(army: Dict[int, int]) -> int:
	total: int = 0
	for unit_type, count in army.items():
		total += int(count) * int(UNIT_STATS[unit_type]["power"])
	return total

def army_cost(army: Dict[int, int]) -> int:
	total: int = 0
	for unit_type, count in army.items():
		total += int(count) * int(UNIT_STATS[unit_type]["cost"])
	return total

def army_power_breakdown(army: Dict[int, int]) -> Tuple[int, int, int]:
	total: int = 0
	melee: int = 0
	ranged: int = 0
	for unit_type, count in army.items():
		power = int(count) * int(UNIT_STATS[unit_type]["power"])
		total += power
		if unit_has_trait(unit_type, RANGED):
			ranged += power
		else:
			melee += power
	return total, melee, ranged

def binomial_sample(rng: random.Random, n: int, p: float) -> int:
	# BattleSimulator._binomial_sample
	if n <= 0 or p <= 0.0:
		return 0
	if p >= 1.0:
		return n
	s = 0
	for _ in range(n):
		if rng.random() < p:
			s += 1
	return s

def percentage_to_ratio(percent: int) -> float:
	ratio = float(percent) / 100.0
	if ratio < 0.0:
		return 0.0
	if ratio > 1.0:
		return 1.0
	return ratio

def multinomial_sample(rng: random.Random, n: int, weights: List[int]) -> List[int]:
	# BattleSimulator._multinomial_sample
	if n <= 0 or not weights:
		return []
	total_weight = 0.0
	for w in weights:
		total_weight += float(w)
	if total_weight <= 0:
		return [0 for _ in weights]

	probs = [float(w) / total_weight for w in weights]
	results = [0 for _ in weights]

	for _ in range(n):
		r = rng.random()
		cumulative = 0.0
		for j, pj in enumerate(probs):
			cumulative += pj
			if r <= cumulative:
				results[j] += 1
				break
	return results

def apply_multiplier_stochastic(rng: random.Random, base_hits: int, mult: float) -> int:
	# BattleSimulator._apply_multiplier_stochastic
	raw = float(base_hits) * float(mult)
	whole = int(raw // 1)
	frac = raw - float(whole)
	if rng.random() < frac:
		whole += 1
	return whole

def get_terrain_attack_multiplier(unit_type: int, grassland: bool) -> float:
	# BattleSimulator._get_terrain_attack_multiplier, with castle_type=NONE always
	mult = 1.0
	if unit_has_trait(unit_type, CHARGE) and grassland:
		mult += CHARGE_BONUS_GRASSLAND
	return mult

def can_attack_ranged_by_ratio(attacking_army: Dict[int, int], defending_army: Dict[int, int]) -> bool:
	# BattleSimulator._can_attack_ranged_by_ratio
	attacker_non_ranged = 0
	defender_non_ranged = 0

	for ut, c in attacking_army.items():
		if not unit_has_trait(ut, RANGED):
			attacker_non_ranged += int(c)

	for ut, c in defending_army.items():
		if not unit_has_trait(ut, RANGED):
			defender_non_ranged += int(c)

	return attacker_non_ranged >= (defender_non_ranged * 3)

def get_valid_targets(attacker_unit_type: int,
					  attacking_army: Dict[int, int],
					  defending_army: Dict[int, int]) -> List[int]:
	# BattleSimulator._get_valid_targets, with disable_siege_traits=false always here
	valid: List[int] = []
	attacker_has_ranged = unit_has_trait(attacker_unit_type, RANGED)
	attacker_has_flanker = unit_has_trait(attacker_unit_type, FLANKER)

	for def_ut, def_count in defending_army.items():
		if int(def_count) <= 0:
			continue

		defender_has_ranged = unit_has_trait(def_ut, RANGED)

		# Rule 1: ranged can target any
		if attacker_has_ranged:
			valid.append(def_ut)
			continue

		# Rule 2: flanker can target any
		if attacker_has_flanker:
			valid.append(def_ut)
			continue

		# Rule 3: non-ranged can target ranged only if ratio met
		if defender_has_ranged:
			if can_attack_ranged_by_ratio(attacking_army, defending_army):
				valid.append(def_ut)
		else:
			valid.append(def_ut)

	return valid

def distribute_hits_to_valid_targets(defending_army: Dict[int, int],
									 valid_targets: List[int],
									 total_hits: int,
									 rng: random.Random) -> Dict[int, int]:
	# BattleSimulator._distribute_hits_to_valid_targets
	if total_hits <= 0 or not valid_targets:
		return {}
	target_counts = [int(defending_army.get(t, 0)) for t in valid_targets]
	distributed = multinomial_sample(rng, total_hits, target_counts)
	out: Dict[int, int] = {}
	for i, t in enumerate(valid_targets):
		if distributed[i] > 0:
			out[t] = distributed[i]
	return out

def defense_resolution_with_attacker_traits(assigned_hits: Dict[int, int],
										   attacker_unit_type: int,
										   rng: random.Random,
										   general_defense_bonus: int) -> Dict[int, int]:
	# BattleSimulator._defense_resolution_with_attacker_traits, castle bonus = 0 here
	kills: Dict[int, int] = {}
	has_armor_piercing = unit_has_trait(attacker_unit_type, ARMOR_PIERCING)
	general_defense_chance = percentage_to_ratio(general_defense_bonus)

	for defender_unit_type, hits in assigned_hits.items():
		hits = int(hits)
		if hits <= 0:
			continue

		# First layer: castle defense (ignored => 0, so hits_after_castle_defense == hits)
		hits_after_castle_defense = hits

		# Second layer: unit armor defense
		base_defense_chance = float(UNIT_STATS[defender_unit_type]["defense"]) / 100.0
		effective_defense_chance = base_defense_chance

		if has_armor_piercing:
			effective_defense_chance = max(0.0, base_defense_chance - ARMOR_PIERCING_DEFENSE_REDUCTION)

		penetration_chance = max(0.0, 1.0 - effective_defense_chance)
		penetrating_hits = binomial_sample(rng, hits_after_castle_defense, penetration_chance)
		if general_defense_chance > 0.0 and penetrating_hits > 0:
			penetrating_hits = binomial_sample(rng, penetrating_hits, 1.0 - general_defense_chance)

		if penetrating_hits > 0:
			kills[defender_unit_type] = penetrating_hits

	return kills

def apply_kills(army: Dict[int, int], kills: Dict[int, int]) -> None:
	# BattleSimulator._apply_kills
	for unit_type, kill_count in kills.items():
		kill_count = int(kill_count)
		if kill_count <= 0:
			continue
		available = int(army.get(unit_type, 0))
		if available <= 0:
			continue
		actual = min(kill_count, available)
		remaining = available - actual
		if remaining > 0:
			army[unit_type] = remaining
		else:
			army.pop(unit_type, None)

def process_unit_attacks(attacking_army: Dict[int, int],
						 defending_army: Dict[int, int],
						 rng: random.Random,
						 efficiency: int,
						 grassland: bool,
						 ranged_only: bool,
						 is_defender: bool = False,
						 assault_percent: int = 100,
						 general_defense_bonus: int = 0) -> Dict[int, int]:
	# Combines logic of:
	# - _process_ranged_unit_attacks when ranged_only=True
	# - _process_unit_attacks when ranged_only=False
	total_kills: Dict[int, int] = {}
	efficiency_modifier = float(efficiency) / 100.0

	for attacker_unit_type, attacker_count in attacking_army.items():
		attacker_count = int(attacker_count)
		if attacker_count <= 0:
			continue

		is_ranged_unit = unit_has_trait(attacker_unit_type, RANGED)
		is_melee_attack = not ranged_only and not is_ranged_unit
		if ranged_only and not is_ranged_unit:
			continue

		base_attack_chance = float(UNIT_STATS[attacker_unit_type]["attack"]) / 100.0
		modified_attack_chance = base_attack_chance * efficiency_modifier
		modified_attack_chance *= get_terrain_attack_multiplier(attacker_unit_type, grassland)
		if is_defender and unit_has_trait(attacker_unit_type, DEFENDER):
			modified_attack_chance *= DEFENDER_ATTACK_MULTIPLIER

		effective_unit_count = attacker_count
		if unit_has_trait(attacker_unit_type, MULTI_ATTACK):
			effective_unit_count *= 2

		hits = binomial_sample(rng, effective_unit_count, modified_attack_chance)
		if is_melee_attack and hits > 0:
			hits = apply_multiplier_stochastic(rng, hits, percentage_to_ratio(assault_percent))
		if hits <= 0:
			continue

		valid_targets = get_valid_targets(attacker_unit_type, attacking_army, defending_army)
		if not valid_targets:
			continue

		target_assigned = distribute_hits_to_valid_targets(defending_army, valid_targets, hits, rng)

		# Long-spears bonus vs cavalry
		if unit_has_trait(attacker_unit_type, LONG_SPEARS):
			for def_ut in list(target_assigned.keys()):
				if is_cavalry_unit(def_ut):
					target_assigned[def_ut] = apply_multiplier_stochastic(
						rng, int(target_assigned[def_ut]), LONG_SPEARS_CAVALRY_MULTIPLIER
					)

		target_kills = defense_resolution_with_attacker_traits(
			target_assigned, attacker_unit_type, rng, general_defense_bonus
		)

		for k, v in target_kills.items():
			total_kills[k] = total_kills.get(k, 0) + int(v)

	return total_kills

def simulate_battle(att: Dict[int, int],
					deff: Dict[int, int],
					seed: int,
					grassland: bool,
					attacker_efficiency: int = 100,
					defender_efficiency: int = 100,
					attacker_assault: int = 100,
					defender_defense_bonus: int = 0) -> Tuple[Dict[int, int], Dict[int, int]]:
	# Mirrors simulate_battle() for non-siege, no garrison, no withdrawal.
	rng = random.Random(seed)

	# Opening ranged volley - both sides, applied simultaneously
	attacker_ranged_kills = process_unit_attacks(
		att, deff, rng, attacker_efficiency, grassland,
		ranged_only=True, is_defender=False, assault_percent=attacker_assault,
		general_defense_bonus=defender_defense_bonus
	)
	defender_ranged_kills = process_unit_attacks(
		deff, att, rng, defender_efficiency, grassland,
		ranged_only=True, is_defender=True, assault_percent=100, general_defense_bonus=0
	)
	apply_kills(deff, attacker_ranged_kills)
	apply_kills(att, defender_ranged_kills)

	# Battle loop
	rounds = 0
	while army_size(att) > 0 and army_size(deff) > 0 and rounds < MAX_ROUNDS:
		rounds += 1
		attacker_kills = process_unit_attacks(
			att, deff, rng, attacker_efficiency, grassland,
			ranged_only=False, is_defender=False, assault_percent=attacker_assault,
			general_defense_bonus=defender_defense_bonus
		)
		defender_kills = process_unit_attacks(
			deff, att, rng, defender_efficiency, grassland,
			ranged_only=False, is_defender=True, assault_percent=100, general_defense_bonus=0
		)
		apply_kills(deff, attacker_kills)
		apply_kills(att, defender_kills)

	return att, deff

def simulate_battle_series(att0: Dict[int, int],
						   def0: Dict[int, int],
						   seed: int,
						   grassland: bool,
						   runs: int = 100,
						   assault: int = 100,
						   defense_bonus: int = 0) -> Tuple[int, int, float, float, Dict[int, int], Dict[int, int]]:
	att_wins: int = 0
	def_wins: int = 0
	att_survival_sum: float = 0.0
	def_survival_sum: float = 0.0
	last_att_res: Dict[int, int] = {}
	last_def_res: Dict[int, int] = {}

	for i in range(runs):
		run_seed = seed + i
		att = dict(att0)
		deff = dict(def0)
		att_res, def_res = simulate_battle(
			att, deff, seed=run_seed, grassland=grassland,
			attacker_efficiency=100, defender_efficiency=100,
			attacker_assault=assault, defender_defense_bonus=defense_bonus
		)
		att_remaining = army_size(att_res)
		def_remaining = army_size(def_res)
		if def_remaining <= 0 and att_remaining > 0:
			att_wins += 1
			att_start = army_size(att0)
			if att_start > 0:
				att_survival_sum += (float(att_remaining) / float(att_start)) * 100.0
		elif att_remaining <= 0 and def_remaining > 0:
			def_wins += 1
			def_start = army_size(def0)
			if def_start > 0:
				def_survival_sum += (float(def_remaining) / float(def_start)) * 100.0
		last_att_res = att_res
		last_def_res = def_res

	return att_wins, def_wins, att_survival_sum, def_survival_sum, last_att_res, last_def_res

# =========================================
# Tkinter UI
# =========================================
class BattleApp:
	def __init__(self, root: tk.Tk):
		self.root = root
		root.title("Battle Tester (Godot Logic)")

		self.entries_att: Dict[int, ttk.Entry] = {}
		self.entries_def: Dict[int, ttk.Entry] = {}

		self.grassland_var = tk.BooleanVar(value=True)
		self.seed_var = tk.StringVar(value="")
		self.fight_text = tk.StringVar(value="Fight")
		self.status_var = tk.StringVar(value="")
		self.keep_seed_var = tk.BooleanVar(value=True)
		self.assault_var = tk.StringVar(value="100")
		self.defense_var = tk.StringVar(value="0")
		self.defense_mod_var = tk.StringVar(value="1")

		# Stored snapshot for Repeat
		self.snapshot: Optional[Tuple[Dict[int, int], Dict[int, int], int, bool, int, int, float]] = None

		frm = ttk.Frame(root, padding=10)
		frm.grid(sticky="nsew")

		ttk.Label(frm, text="Unit").grid(row=0, column=0, sticky="w")
		ttk.Label(frm, text="Attackers").grid(row=0, column=1, sticky="w")
		ttk.Label(frm, text="Defenders").grid(row=0, column=2, sticky="w")

		for i, ut in enumerate(DISPLAY_ORDER, start=1):
			ttk.Label(frm, text=NAMES[ut]).grid(row=i, column=0, sticky="w", padx=(0, 10))
			ea = ttk.Entry(frm, width=10)
			ed = ttk.Entry(frm, width=10)
			ea.insert(0, "0")
			ed.insert(0, "0")
			ea.grid(row=i, column=1, sticky="w")
			ed.grid(row=i, column=2, sticky="w")
			self.entries_att[ut] = ea
			self.entries_def[ut] = ed

		opts_row = len(DISPLAY_ORDER) + 1
		ttk.Checkbutton(frm, text="Grassland", variable=self.grassland_var).grid(row=opts_row, column=0, sticky="w")
		ttk.Checkbutton(frm, text="Keep seed", variable=self.keep_seed_var).grid(row=opts_row, column=1, sticky="w")

		ttk.Label(frm, text="Seed").grid(row=opts_row, column=1, sticky="e")
		ttk.Entry(frm, textvariable=self.seed_var, width=12).grid(row=opts_row, column=2, sticky="w")

		params_row = opts_row + 1
		ttk.Label(frm, text="Assault % (attackers)").grid(row=params_row, column=0, sticky="e", padx=(0, 6))
		ttk.Entry(frm, textvariable=self.assault_var, width=8).grid(row=params_row, column=1, sticky="w")
		ttk.Label(frm, text="Defense % (defenders)").grid(row=params_row, column=2, sticky="e", padx=(6, 0))
		ttk.Entry(frm, textvariable=self.defense_var, width=8).grid(row=params_row, column=3, sticky="w")

		mod_row = params_row + 1
		ttk.Label(frm, text="Defense mod (0-1)").grid(row=mod_row, column=2, sticky="e", padx=(6, 0))
		ttk.Entry(frm, textvariable=self.defense_mod_var, width=8).grid(row=mod_row, column=3, sticky="w")

		btn_row = mod_row + 1
		ttk.Button(frm, text="Reset", command=self.on_reset).grid(row=btn_row, column=0, sticky="ew", pady=(8, 0))
		ttk.Button(frm, textvariable=self.fight_text, command=self.on_fight_or_repeat).grid(row=btn_row, column=1, sticky="ew", pady=(8, 0))
		ttk.Button(frm, text="New Battle", command=self.on_new_battle).grid(row=btn_row, column=2, sticky="ew", pady=(8, 0))

		status_row = btn_row + 1
		ttk.Label(frm, textvariable=self.status_var).grid(row=status_row, column=0, columnspan=4, sticky="w", pady=(8, 0))

	def _read_army(self, entries: Dict[int, ttk.Entry]) -> Dict[int, int]:
		army: Dict[int, int] = {}
		for ut in DISPLAY_ORDER:
			e = entries[ut]
			txt = e.get().strip()
			if txt == "":
				val = 0
			else:
				try:
					val = int(txt)
				except ValueError:
					val = 0
			if val > 0:
				army[ut] = val
		return army

	def _write_army(self, entries: Dict[int, ttk.Entry], army: Dict[int, int]) -> None:
		for ut in DISPLAY_ORDER:
			e = entries[ut]
			e.delete(0, tk.END)
			e.insert(0, str(int(army.get(ut, 0))))

	def _get_seed_int(self, force_new: bool = False) -> int:
		"""
		Returns seed according to 'Keep seed' checkbox.
		If force_new=True, always generates a new seed.
		"""
		if force_new or not self.keep_seed_var.get():
			seed = random.randint(0, 2**31 - 1)
			self.seed_var.set(str(seed))
			return seed

		txt = self.seed_var.get().strip()
		if txt == "":
			seed = random.randint(0, 2**31 - 1)
			self.seed_var.set(str(seed))
			return seed

		try:
			return int(txt)
		except ValueError:
			seed = random.randint(0, 2**31 - 1)
			self.seed_var.set(str(seed))
			return seed

	def _read_percentage_var(self, var: tk.StringVar, default: int) -> int:
		txt = var.get().strip()
		if txt == "":
			return default
		try:
			return int(txt)
		except ValueError:
			return default

	def _read_ratio_var(self, var: tk.StringVar, default: float) -> float:
		txt = var.get().strip()
		if txt == "":
			return default
		try:
			val = float(txt)
		except ValueError:
			return default
		if val < 0.0:
			return 0.0
		if val > 1.0:
			return 1.0
		return val


	def on_fight_or_repeat(self) -> None:
		try:
			if self.fight_text.get() == "Fight" or self.snapshot is None:
				att0 = self._read_army(self.entries_att)
				def0 = self._read_army(self.entries_def)
				seed = self._get_seed_int(force_new=False)
				grass = bool(self.grassland_var.get())
				assault = self._read_percentage_var(self.assault_var, 100)
				defense_bonus = self._read_percentage_var(self.defense_var, 0)
				defense_mod = self._read_ratio_var(self.defense_mod_var, 1.0)
				self.snapshot = (dict(att0), dict(def0), seed, grass, assault, defense_bonus, defense_mod)
				self.fight_text.set("Repeat")
			else:
				# Repeat
				att0, def0, _, grass, assault, defense_bonus, defense_mod = self.snapshot
				seed = self._get_seed_int(force_new=not self.keep_seed_var.get())
				self.snapshot = (dict(att0), dict(def0), seed, grass, assault, defense_bonus, defense_mod)
			self.grassland_var.set(grass)
			self.seed_var.set(str(seed))
			self.assault_var.set(str(assault))
			self.defense_var.set(str(defense_bonus))
			self.defense_mod_var.set(str(defense_mod))
			self._write_army(self.entries_att, att0)
			self._write_army(self.entries_def, def0)

			runs: int = 100
			att_wins, def_wins, att_survival_sum, def_survival_sum, att_res, def_res = simulate_battle_series(
				att0, def0, seed=seed, grassland=grass, runs=runs, assault=assault, defense_bonus=defense_bonus
			)

			att_win_rate: float = (float(att_wins) / float(runs)) * 100.0
			def_win_rate: float = (float(def_wins) / float(runs)) * 100.0
			att_survival_avg: float = att_survival_sum / float(att_wins) if att_wins > 0 else 0.0
			def_survival_avg: float = def_survival_sum / float(def_wins) if def_wins > 0 else 0.0

			att_power_total, att_power_melee, att_power_ranged = army_power_breakdown(att0)
			def_power_total, _, _ = army_power_breakdown(def0)
			assault_ratio = percentage_to_ratio(assault)
			defense_ratio = percentage_to_ratio(defense_bonus)
			defense_mod_val = self._read_ratio_var(self.defense_mod_var, 1.0)
			dps: float = float(att_power_ranged) + (float(att_power_melee) * assault_ratio)
			ehp: float = float(att_power_total)
			att_power_mod: int = int(math.sqrt(dps * ehp))
			defense_base: float = max(0.0001, 1.0 - defense_ratio)
			def_power_mod: int = int(float(def_power_total) * ((1.0 / defense_base) ** defense_mod_val))
			att_cost: int = army_cost(att0)
			def_cost: int = army_cost(def0)

			self._write_army(self.entries_att, att_res)
			self._write_army(self.entries_def, def_res)

			status_text = (
				f"Win ratio: {round(att_win_rate)}% ({round(att_survival_avg)}%) - "
				f"{round(def_win_rate)}% ({round(def_survival_avg)}%)\n"
				f"Power: {att_power_total} ({att_power_mod}) vs {def_power_total} ({def_power_mod})\n"
				f"Cost: {att_cost} vs {def_cost}"
			)
			self.status_var.set(status_text)
		except Exception as ex:
			# Make failures visible (no silent nothing)
			self.status_var.set(f"ERROR: {ex!r}")

	def on_new_battle(self) -> None:
		self.snapshot = None
		self.fight_text.set("Fight")
		self.grassland_var.set(True)
		self.status_var.set("")
		self.assault_var.set("100")
		self.defense_var.set("0")
		self.defense_mod_var.set("1")

		if not self.keep_seed_var.get():
			seed = random.randint(0, 2**31 - 1)
			self.seed_var.set(str(seed))

		zeros = {ut: 0 for ut in DISPLAY_ORDER}
		self._write_army(self.entries_att, zeros)
		self._write_army(self.entries_def, zeros)

	def on_reset(self) -> None:
		if self.snapshot is None:
			self.status_var.set("No snapshot to reset.")
			return

		att0: Dict[int, int]
		def0: Dict[int, int]
		seed_snapshot: int
		grass_snapshot: bool
		assault_snapshot: int
		defense_snapshot: int
		defense_mod_snapshot: float
		att0, def0, seed_snapshot, grass_snapshot, assault_snapshot, defense_snapshot, defense_mod_snapshot = self.snapshot

		self.fight_text.set("Fight")
		self.grassland_var.set(grass_snapshot)
		self.seed_var.set(str(seed_snapshot))
		self.assault_var.set(str(assault_snapshot))
		self.defense_var.set(str(defense_snapshot))
		self.defense_mod_var.set(str(defense_mod_snapshot))

		self._write_army(self.entries_att, att0)
		self._write_army(self.entries_def, def0)
		self.status_var.set("Reset to snapshot (edit counts, then Fight).")


def main() -> None:
	root = tk.Tk()
	BattleApp(root)
	root.mainloop()

if __name__ == "__main__":
	main()
