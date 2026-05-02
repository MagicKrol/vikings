#!/usr/bin/env python3
import tkinter as tk
from tkinter import ttk
import random
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
MAX_ROUNDS = 1000

# =========================================
# UNIT_STATS copied from GameParameters.gd
# (only attack/defense/traits are needed here)
# =========================================
UNIT_STATS = {
    PEASANTS: {
        "attack": 5,
        "defense": 10,
        "traits": [SIEGE_LABORER],
        "power": 2,
        "cost": 1,
    },
    SPEARMEN: {
        "attack": 8,
        "defense": 25,
        "traits": [LONG_SPEARS, SIEGE_LABORER, DEFENDER],
        "power": 3,
        "cost": 2,
    },
    SWORDSMEN: {
        "attack": 12,
        "defense": 35,
        "traits": [SIEGE_LABORER],
        "power": 4,
        "cost": 3,
    },
    ARCHERS: {
        "attack": 10,
        "defense": 15,
        "traits": [RANGED, BACK_RANK],
        "power": 4,
        "cost": 3,
    },
    CROSSBOWMEN: {
        "attack": 8,
        "defense": 15,
        "traits": [RANGED, ARMOR_PIERCING, BACK_RANK],
        "power": 3,
        "cost": 3,
    },
    HORSEMEN: {
        "attack": 12,
        "defense": 25,
        "traits": [MOBILITY, FLANKER, CHARGE],
        "power": 5,
        "cost": 4,
    },
    KNIGHTS: {
        "attack": 25,
        "defense": 70,
        "traits": [],
        "power": 10,
        "cost": 6,
    },
    MOUNTED_KNIGHTS: {
        "attack": 30,
        "defense": 70,
        "traits": [FLANKER, CHARGE],
        "power": 13,
        "cost": 8,
    },
    ROYAL_GUARD: {
        "attack": 40,
        "defense": 90,
        "traits": [MULTI_ATTACK, ARMOR_PIERCING],
        "power": 15,
        "cost": 15,
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
                                           rng: random.Random) -> Dict[int, int]:
    # BattleSimulator._defense_resolution_with_attacker_traits, castle bonus = 0 here
    kills: Dict[int, int] = {}
    has_armor_piercing = unit_has_trait(attacker_unit_type, ARMOR_PIERCING)

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
                         ranged_only: bool) -> Dict[int, int]:
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
        if ranged_only and not is_ranged_unit:
            continue

        base_attack_chance = float(UNIT_STATS[attacker_unit_type]["attack"]) / 100.0
        modified_attack_chance = base_attack_chance * efficiency_modifier
        modified_attack_chance *= get_terrain_attack_multiplier(attacker_unit_type, grassland)

        effective_unit_count = attacker_count
        if unit_has_trait(attacker_unit_type, MULTI_ATTACK):
            effective_unit_count *= 2

        hits = binomial_sample(rng, effective_unit_count, modified_attack_chance)
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

        target_kills = defense_resolution_with_attacker_traits(target_assigned, attacker_unit_type, rng)

        for k, v in target_kills.items():
            total_kills[k] = total_kills.get(k, 0) + int(v)

    return total_kills

def simulate_battle(att: Dict[int, int],
                    deff: Dict[int, int],
                    seed: int,
                    grassland: bool,
                    attacker_efficiency: int = 100,
                    defender_efficiency: int = 100) -> Tuple[Dict[int, int], Dict[int, int]]:
    # Mirrors simulate_battle() for non-siege, no garrison, no withdrawal.
    rng = random.Random(seed)

    # Opening ranged volley - both sides, applied simultaneously
    attacker_ranged_kills = process_unit_attacks(att, deff, rng, attacker_efficiency, grassland, ranged_only=True)
    defender_ranged_kills = process_unit_attacks(deff, att, rng, defender_efficiency, grassland, ranged_only=True)
    apply_kills(deff, attacker_ranged_kills)
    apply_kills(att, defender_ranged_kills)

    # Battle loop
    rounds = 0
    while army_size(att) > 0 and army_size(deff) > 0 and rounds < MAX_ROUNDS:
        rounds += 1
        attacker_kills = process_unit_attacks(att, deff, rng, attacker_efficiency, grassland, ranged_only=False)
        defender_kills = process_unit_attacks(deff, att, rng, defender_efficiency, grassland, ranged_only=False)
        apply_kills(deff, attacker_kills)
        apply_kills(att, defender_kills)

    return att, deff

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

        # Stored snapshot for Repeat
        self.snapshot: Optional[Tuple[Dict[int, int], Dict[int, int], int, bool]] = None

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

        btn_row = opts_row + 1
        ttk.Button(frm, textvariable=self.fight_text, command=self.on_fight_or_repeat).grid(row=btn_row, column=1, sticky="ew", pady=(8, 0))
        ttk.Button(frm, text="New Battle", command=self.on_new_battle).grid(row=btn_row, column=2, sticky="ew", pady=(8, 0))

        status_row = btn_row + 1
        ttk.Label(frm, textvariable=self.status_var).grid(row=status_row, column=0, columnspan=3, sticky="w", pady=(8, 0))

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


    def on_fight_or_repeat(self) -> None:
        try:
            if self.fight_text.get() == "Fight" or self.snapshot is None:
                att0 = self._read_army(self.entries_att)
                def0 = self._read_army(self.entries_def)
                seed = self._get_seed_int(force_new=False)
                grass = bool(self.grassland_var.get())
                self.snapshot = (att0, def0, seed, grass)
                self.fight_text.set("Repeat")
            else:
                # Repeat
                att0, def0, _, grass = self.snapshot
                seed = self._get_seed_int(force_new=not self.keep_seed_var.get())
                self.snapshot = (att0, def0, seed, grass)
            self.grassland_var.set(grass)
            self.seed_var.set(str(seed))
            self._write_army(self.entries_att, att0)
            self._write_army(self.entries_def, def0)

            # Run battle from restored snapshot
            att = dict(att0)
            deff = dict(def0)
            att_res, def_res = simulate_battle(att, deff, seed=seed, grassland=grass,
                                               attacker_efficiency=100, defender_efficiency=100)

            # Update fields with remaining units (your requirement)
            self._write_army(self.entries_att, att_res)
            self._write_army(self.entries_def, def_res)

            self.status_var.set("Battle resolved (remaining units updated).")
        except Exception as ex:
            # Make failures visible (no silent nothing)
            self.status_var.set(f"ERROR: {ex!r}")

    def on_new_battle(self) -> None:
        self.snapshot = None
        self.fight_text.set("Fight")
        self.grassland_var.set(True)
        self.status_var.set("")

        if not self.keep_seed_var.get():
            seed = random.randint(0, 2**31 - 1)
            self.seed_var.set(str(seed))

        zeros = {ut: 0 for ut in DISPLAY_ORDER}
        self._write_army(self.entries_att, zeros)
        self._write_army(self.entries_def, zeros)


def main() -> None:
    root = tk.Tk()
    BattleApp(root)
    root.mainloop()

if __name__ == "__main__":
    main()
