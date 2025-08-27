#!/usr/bin/env python3
"""
Turn-based battle simulator.

Key features
- Vectorized probability resolution using Binomial / Multinomial (NumPy RNG)
- Distributes hits proportionally across enemy unit categories (including different current HP buckets)
- Defense checks per target category
- Simultaneous resolution: both sides' wounds are applied after both attack phases
- Tracks detailed round-by-round report and final summary

Usage
-----
from battle_sim import simulate_battle, default_units, make_army

army_a = make_army({"Peasants": 95, "Swordsmen": 5})
army_b = make_army({"Peasants": 90, "Peasants_1HP": 5, "Swordsmen": 4, "Swordsmen_1HP": 1})
report = simulate_battle(army_a, army_b, seed=42)
print(report["summary"])
"""

from __future__ import annotations
from dataclasses import dataclass
from typing import Dict, Tuple, List, Any
from collections import defaultdict, Counter
import numpy as np

# ------------------------- Unit definitions -------------------------

@dataclass(frozen=True)
class UnitDef:
    gold: int = 0
    food: float = 0.0
    wood: int = 0
    iron: int = 0
    attack: int = 0       # percent chance per unit to produce a hit (before defense)
    defense: int = 0      # percent chance per hit to be deflected

# Base unit stats (percentages are 0-100)
default_units: Dict[str, UnitDef] = {
    "Peasants": UnitDef(gold=0, food=0.1, attack=5, defense=10),
    "Spearmen": UnitDef(gold=1, food=0.1, attack=10, defense=25),
    "Swordsmen": UnitDef(gold=2, food=0.1, attack=30, defense=40),
    "Archers": UnitDef(gold=3, food=0.1, wood=1, attack=25, defense=15),
    "Crossbowmen": UnitDef(gold=2, food=0.1, wood=1, attack=20, defense=15),
    "Horsemen": UnitDef(gold=5, food=0.2, attack=30, defense=30),
    "Knights": UnitDef(gold=10, food=0.2, iron=1, attack=60, defense=60),
    "Mounted Knights": UnitDef(gold=15, food=0.4, iron=1, attack=65, defense=60),
    "Royal Guard": UnitDef(gold=20, food=0.3, iron=1, attack=80, defense=80),
}

# ------------------------- Army representation -------------------------
# Army is a mapping {unit_type: count}
Army = Dict[str, int]

def make_army(spec: Dict[str, int], unit_defs: Dict[str, UnitDef] = default_units) -> Army:
    """
    Convert a friendly spec like {"Peasants": 95, "Swordsmen": 5}
    into an Army mapping {unit_type: count}.
    """
    army: Army = {}
    for unit_type, count in spec.items():
        if count <= 0:
            continue
        if unit_type not in unit_defs:
            raise ValueError(f"Unknown unit type: {unit_type}")
        army[unit_type] = int(count)
    return army

def army_size(army: Army) -> int:
    return sum(army.values())

def alive_types(army: Army) -> List[str]:
    return [unit_type for unit_type, count in army.items() if count > 0]

# ------------------------- Combat resolution -------------------------

def _binomial_rng(rng: np.random.Generator, n: int, p: float) -> int:
    if n <= 0 or p <= 0:
        return 0
    p = min(max(p, 0.0), 1.0)
    return int(rng.binomial(n, p))

def _multinomial_rng(rng: np.random.Generator, n: int, probs: np.ndarray) -> np.ndarray:
    if n <= 0:
        return np.zeros_like(probs, dtype=int)
    # normalize defensively
    total = probs.sum()
    if total <= 0:
        # if somehow no defenders, return zeros
        return np.zeros_like(probs, dtype=int)
    probs = probs / total
    draws = rng.multinomial(n, probs)
    return draws.astype(int)

def _attacks_to_hits(attacker: Army, rng: np.random.Generator) -> int:
    """
    For each unit type, sample # of successful hits via Binomial.
    Sum over all unit types to get total hits produced by the attacking army.
    """
    total_hits = 0
    for unit_type, count in attacker.items():
        if count <= 0:
            continue
        atk_pct = default_units[unit_type].attack / 100.0
        total_hits += _binomial_rng(rng, count, atk_pct)
    return int(total_hits)

def _distribute_hits_across_defender(defender: Army, total_hits: int, rng: np.random.Generator) -> Dict[str, int]:
    """
    Distribute total hits proportionally across all defender unit types
    using a Multinomial with probabilities proportional to counts.
    """
    unit_types = alive_types(defender)
    if not unit_types or total_hits <= 0:
        return {}
    counts = np.array([defender[unit_type] for unit_type in unit_types], dtype=float)
    draws = _multinomial_rng(rng, total_hits, counts)
    return {unit_types[i]: int(draws[i]) for i in range(len(unit_types)) if draws[i] > 0}

def _defense_resolution(assigned_hits: Dict[str, int], rng: np.random.Generator) -> Dict[str, int]:
    """
    For each defender unit type, some assigned hits are deflected by defense %.
    Return penetrating hits (kills) per unit type.
    """
    kills: Dict[str, int] = {}
    for unit_type, hits in assigned_hits.items():
        if hits <= 0:
            continue
        def_pct = default_units[unit_type].defense / 100.0
        # probability to penetrate (kill) = 1 - def_pct
        pen = _binomial_rng(rng, hits, max(0.0, 1.0 - def_pct))
        if pen > 0:
            kills[unit_type] = pen
    return kills

def _apply_kills(army: Army, kills: Dict[str, int]) -> Dict[str, int]:
    """
    Apply kills directly to the army. Hit = Death.
    Returns actual casualties per unit type.
    """
    actual_kills: Dict[str, int] = {}
    
    for unit_type, kill_count in kills.items():
        if kill_count <= 0:
            continue
        available = army.get(unit_type, 0)
        if available <= 0:
            continue
        
        # Can't kill more than what's available
        actual_kill_count = min(kill_count, available)
        army[unit_type] = available - actual_kill_count
        
        # Remove empty unit types
        if army[unit_type] <= 0:
            del army[unit_type]
            
        actual_kills[unit_type] = actual_kill_count
    
    return actual_kills

# ------------------------- Battle loop -------------------------

def simulate_battle(army_a: Army,
                    army_b: Army,
                    unit_defs: Dict[str, UnitDef] = default_units,
                    seed: int | None = None,
                    max_rounds: int = 100_000) -> Dict[str, Any]:
    """
    Simulate until one army is fully dead or max_rounds reached.
    Returns a report with detailed rounds and a final summary.
    """
    rng = np.random.default_rng(seed)

    # Deep copies so we don't mutate inputs
    A: Army = dict(army_a)
    B: Army = dict(army_b)

    rounds: List[Dict[str, Any]] = []
    round_idx = 0

    while army_size(A) > 0 and army_size(B) > 0 and round_idx < max_rounds:
        round_idx += 1

        # --- Attack phases (compute kills without applying) ---
        # A attacks B
        a_hits = _attacks_to_hits(A, rng)
        a_assign = _distribute_hits_across_defender(B, a_hits, rng)
        a_kills = _defense_resolution(a_assign, rng)

        # B attacks A
        b_hits = _attacks_to_hits(B, rng)
        b_assign = _distribute_hits_across_defender(A, b_hits, rng)
        b_kills = _defense_resolution(b_assign, rng)

        # --- Apply kills simultaneously ---
        a_deaths = _apply_kills(B, a_kills)  # A kills units in B
        b_deaths = _apply_kills(A, b_kills)  # B kills units in A

        round_report = {
            "round": round_idx,
            "A": {
                "size_end": army_size(A),
                "hits": a_hits,
                "assigned_hits": a_assign,
                "kills_after_defense": a_kills,
                "kills": a_deaths,
                "army": dict(A),
            },
            "B": {
                "size_end": army_size(B),
                "hits": b_hits,
                "assigned_hits": b_assign,
                "kills_after_defense": b_kills,
                "kills": b_deaths,
                "army": dict(B),
            },
        }
        rounds.append(round_report)

    # Determine winner
    if army_size(A) > 0 and army_size(B) == 0:
        winner = "A"
    elif army_size(B) > 0 and army_size(A) == 0:
        winner = "B"
    else:
        winner = "Draw/MaxRounds"

    summary = {
        "winner": winner,
        "rounds": round_idx,
        "final_A": dict(A),
        "final_B": dict(B),
        "final_sizes": {"A": army_size(A), "B": army_size(B)},
    }

    return {
        "rounds": rounds,
        "summary": summary,
    }

# ------------------------- Convenience -------------------------

def simulate_battle_from_specs(spec_a: Dict[str, int],
                               spec_b: Dict[str, int],
                               seed: int | None = None) -> Dict[str, Any]:
    A = make_army(spec_a)
    B = make_army(spec_b)
    return simulate_battle(A, B, seed=seed)

# ------------------------- CLI demo -------------------------

def _demo():
    A = make_army({"Peasants": 95, "Swordsmen": 5})
    B = make_army({"Peasants": 95, "Swordsmen": 5})
    report = simulate_battle(A, B, seed=123)
    import json
    print(json.dumps(report["summary"], indent=2))

if __name__ == "__main__":
    _demo()
