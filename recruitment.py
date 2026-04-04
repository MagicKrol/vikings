import math
import random
import tkinter as tk
from tkinter import ttk, messagebox
from typing import Dict, Optional, Sequence, Tuple

UNITS = {
	"peasants": {"gold": 1, "wood": 0, "iron": 0},
	"spearmen": {"gold": 2, "wood": 0, "iron": 0},
	"swordsmen": {"gold": 3, "wood": 0, "iron": 0},
	"archers": {"gold": 3, "wood": 1, "iron": 0},
	"crossbowmen": {"gold": 3, "wood": 1, "iron": 0},
	"horsemen": {"gold": 4, "wood": 0, "iron": 0},
	"knights": {"gold": 6, "wood": 0, "iron": 1},
	"mounted_knights": {"gold": 9, "wood": 0, "iron": 1},
	"royal_guard": {"gold": 12, "wood": 0, "iron": 2},
}

TIERS = {
	"peasants": 1,
	"archers": 2,
	"spearmen": 2,
	"swordsmen": 3,
	"horsemen": 3,
	"crossbowmen": 3,
	"knights": 4,
	"mounted_knights": 4,
	"royal_guard": 5,
}

BASE_ORDER = [
	"peasants",
	"spearmen",
	"swordsmen",
	"knights",
	"royal_guard",
]

ORDER = [
	"peasants",
	"spearmen",
	"swordsmen",
	"archers",
	"crossbowmen",
	"horsemen",
	"knights",
	"mounted_knights",
	"royal_guard",
]

SIGMA = 1.6
AMPLITUDE = 10.0
WEIGHT_CUTOFF_X = 5.0
MIN_RATIO = 0.5
MAX_RATIO = 5.0
MAX_SHIFT = 4.0
RANGED_MIN_SHARE = 0.2
RANGED_MAX_SHARE = 0.3
RANGED_UNITS = ("archers", "crossbowmen")

GRAPH_WIDTH = 520
GRAPH_HEIGHT = 260
GRAPH_MARGIN = 28

def compute_shift(gold: int, recruits: int) -> float:
	if recruits <= 0:
		return MAX_SHIFT
	ratio = float(gold) / float(recruits)
	if ratio <= MIN_RATIO:
		return 0.0
	if ratio >= MAX_RATIO:
		return MAX_SHIFT
	span = MAX_RATIO - MIN_RATIO
	return ((ratio - MIN_RATIO) / span) * MAX_SHIFT

def gaussian_weight(x: float, mu: float) -> float:
	if x >= WEIGHT_CUTOFF_X:
		return 0.0
	exponent = -((x - mu) ** 2) / (2.0 * (SIGMA ** 2))
	return AMPLITUDE * math.exp(exponent)

def build_base_weights(mu: float) -> Dict[str, float]:
	weights: Dict[str, float] = {}
	for idx, unit in enumerate(BASE_ORDER):
		weights[unit] = gaussian_weight(float(idx), mu)
	return weights

def compute_horsemen_share(grassland_global: int, grassland_frontier: int) -> float:
	return (float(grassland_global) + float(grassland_frontier)) / 200.0

def split_cavalry_weights(base_weights: Dict[str, float], horsemen_share: float) -> Dict[str, float]:
	weights = dict(base_weights)
	swordsmen_bucket = base_weights.get("swordsmen", 0.0)
	knights_bucket = base_weights.get("knights", 0.0)
	weights["swordsmen"] = swordsmen_bucket * (1.0 - horsemen_share)
	weights["horsemen"] = swordsmen_bucket * horsemen_share
	weights["knights"] = knights_bucket * (1.0 - horsemen_share)
	weights["mounted_knights"] = knights_bucket * horsemen_share
	return weights

def add_ranged_weights(base_weights: Dict[str, float], rng: random.Random) -> Dict[str, float]:
	weights = dict(base_weights)
	total_base = sum(base_weights.values())
	if total_base <= 0.0:
		weights["archers"] = 0.0
		weights["crossbowmen"] = 0.0
		return weights
	ranged_roll = rng.uniform(RANGED_MIN_SHARE, RANGED_MAX_SHARE)
	ranged_pool = total_base * ranged_roll
	archer_mass = (
		base_weights.get("peasants", 0.0) +
		base_weights.get("spearmen", 0.0) +
		base_weights.get("swordsmen", 0.0) +
		base_weights.get("horsemen", 0.0)
	)
	crossbow_mass = (
		base_weights.get("knights", 0.0) +
		base_weights.get("mounted_knights", 0.0) +
		base_weights.get("royal_guard", 0.0)
	)
	total_ranged_mass = archer_mass + crossbow_mass
	if total_ranged_mass <= 0.0:
		weights["archers"] = 0.0
		weights["crossbowmen"] = 0.0
		return weights
	weights["archers"] = ranged_pool * (archer_mass / total_ranged_mass)
	weights["crossbowmen"] = ranged_pool * (crossbow_mass / total_ranged_mass)
	return weights

def apply_tier_mask(weights: Dict[str, float], tier_cap: int) -> Dict[str, float]:
	masked = {}
	for unit, value in weights.items():
		if TIERS.get(unit, 5) > tier_cap:
			masked[unit] = 0.0
		else:
			masked[unit] = value
	return masked

def normalize_weights(weights: Dict[str, float]) -> Dict[str, float]:
	total = sum(weights.values())
	if total <= 0.0:
		return {unit: 0.0 for unit in ORDER}
	return {unit: weights[unit] / total for unit in ORDER}

def total_cost(counts: Dict[str, int]) -> Tuple[int, int, int]:
	gold = wood = iron = 0
	for unit in ORDER:
		costs = UNITS[unit]
		count = int(counts.get(unit, 0))
		gold += count * costs["gold"]
		wood += count * costs["wood"]
		iron += count * costs["iron"]
	return gold, wood, iron

def count_ranged_units(counts: Dict[str, int]) -> int:
	return int(counts.get("archers", 0)) + int(counts.get("crossbowmen", 0))

def merge_counts(first: Dict[str, int], second: Dict[str, int]) -> Dict[str, int]:
	return {unit: int(first.get(unit, 0)) + int(second.get(unit, 0)) for unit in ORDER}

def compute_ranged_target(recruits: int, weights: Dict[str, float], budgets: Dict[str, int]) -> int:
	if recruits <= 0:
		return 0
	ranged_weight = float(weights.get("archers", 0.0)) + float(weights.get("crossbowmen", 0.0))
	if ranged_weight <= 0.0:
		return 0
	min_ranged = int(math.ceil(float(recruits) * RANGED_MIN_SHARE))
	max_ranged = int(math.floor(float(recruits) * RANGED_MAX_SHARE))
	if max_ranged < min_ranged:
		max_ranged = min_ranged
	total_weight = sum(weights.values())
	if total_weight <= 0.0:
		target = min_ranged
	else:
		target = int(round((ranged_weight / total_weight) * float(recruits)))
	target = max(min_ranged, min(max_ranged, target))
	max_gold_ranged = budgets["gold"] // 3
	max_wood_ranged = budgets["wood"]
	max_possible = min(recruits, max_gold_ranged, max_wood_ranged)
	return max(0, min(target, max_possible))

def _ranged_share_ratio(ranged_assigned: int, total_recruited: int) -> float:
	if total_recruited <= 0:
		return 0.0
	return float(ranged_assigned) / float(total_recruited)

def _ranged_band_distance(share_ratio: float) -> float:
	if share_ratio < RANGED_MIN_SHARE:
		return RANGED_MIN_SHARE - share_ratio
	if share_ratio > RANGED_MAX_SHARE:
		return share_ratio - RANGED_MAX_SHARE
	return 0.0

def _simulate_two_pass_plan(
	total_recruits: int,
	weights: Dict[str, float],
	budgets: Dict[str, int],
	ranged_target: int
) -> Dict[str, object]:
	ranged_counts, ranged_spent, ranged_left, ranged_rate = purchase_units(
		weights,
		budgets,
		ranged_target,
		RANGED_UNITS
	)
	remaining_recruits = max(0, total_recruits - sum(ranged_counts.values()))
	melee_weights = dict(weights)
	melee_weights["archers"] = 0.0
	melee_weights["crossbowmen"] = 0.0
	melee_budgets = {
		"gold": ranged_left[0],
		"wood": ranged_left[1],
		"iron": ranged_left[2],
	}
	melee_counts, melee_spent, left, melee_rate = purchase_units(melee_weights, melee_budgets, remaining_recruits)
	counts = merge_counts(ranged_counts, melee_counts)
	spent = (
		ranged_spent[0] + melee_spent[0],
		ranged_spent[1] + melee_spent[1],
		ranged_spent[2] + melee_spent[2],
	)
	rate = melee_rate if remaining_recruits > 0 else ranged_rate
	final_recruits = sum(counts.values())
	ranged_assigned = count_ranged_units(counts)
	share_ratio = _ranged_share_ratio(ranged_assigned, final_recruits)
	midpoint = (RANGED_MIN_SHARE + RANGED_MAX_SHARE) * 0.5
	return {
		"ranged_target": ranged_target,
		"counts": counts,
		"spent": spent,
		"left": left,
		"rate": rate,
		"final_recruits": final_recruits,
		"ranged_assigned": ranged_assigned,
		"share_ratio": share_ratio,
		"in_band": share_ratio >= RANGED_MIN_SHARE and share_ratio <= RANGED_MAX_SHARE,
		"band_distance": _ranged_band_distance(share_ratio),
		"midpoint_distance": abs(share_ratio - midpoint),
	}

def _is_better_plan_candidate(candidate: Dict[str, object], current_best: Optional[Dict[str, object]]) -> bool:
	if current_best is None:
		return True
	candidate_in_band = bool(candidate["in_band"])
	current_in_band = bool(current_best["in_band"])
	if candidate_in_band != current_in_band:
		return candidate_in_band
	if candidate_in_band:
		if int(candidate["final_recruits"]) != int(current_best["final_recruits"]):
			return int(candidate["final_recruits"]) > int(current_best["final_recruits"])
		if float(candidate["midpoint_distance"]) != float(current_best["midpoint_distance"]):
			return float(candidate["midpoint_distance"]) < float(current_best["midpoint_distance"])
		return int(candidate["ranged_target"]) < int(current_best["ranged_target"])
	if float(candidate["band_distance"]) != float(current_best["band_distance"]):
		return float(candidate["band_distance"]) < float(current_best["band_distance"])
	if int(candidate["final_recruits"]) != int(current_best["final_recruits"]):
		return int(candidate["final_recruits"]) > int(current_best["final_recruits"])
	if float(candidate["midpoint_distance"]) != float(current_best["midpoint_distance"]):
		return float(candidate["midpoint_distance"]) < float(current_best["midpoint_distance"])
	return int(candidate["ranged_target"]) < int(current_best["ranged_target"])

def choose_best_two_pass_plan(total_recruits: int, weights: Dict[str, float], budgets: Dict[str, int]) -> Dict[str, object]:
	ranged_weight = float(weights.get("archers", 0.0)) + float(weights.get("crossbowmen", 0.0))
	max_gold_ranged = budgets["gold"] // 3
	max_wood_ranged = budgets["wood"]
	max_possible = max(0, min(total_recruits, max_gold_ranged, max_wood_ranged))
	if total_recruits <= 0 or max_possible <= 0 or ranged_weight <= 0.0:
		return _simulate_two_pass_plan(total_recruits, weights, budgets, 0)
	initial_target = compute_ranged_target(total_recruits, weights, budgets)
	targets = list(range(max_possible + 1))
	if initial_target in targets:
		targets.remove(initial_target)
		targets.insert(0, initial_target)
	best: Optional[Dict[str, object]] = None
	for ranged_target in targets:
		candidate = _simulate_two_pass_plan(total_recruits, weights, budgets, ranged_target)
		if _is_better_plan_candidate(candidate, best):
			best = candidate
	if best is None:
		return _simulate_two_pass_plan(total_recruits, weights, budgets, 0)
	return best

def purchase_units(
	weights: Dict[str, float],
	budgets: Dict[str, int],
	recruits: int,
	allowed_units: Optional[Sequence[str]] = None
) -> Tuple[Dict[str, int], Tuple[int, int, int], Tuple[int, int, int], float]:
	counts = {unit: 0 for unit in ORDER}
	gold = budgets["gold"]
	wood = budgets["wood"]
	iron = budgets["iron"]
	recruits_left = max(0, recruits)
	active_units = ORDER if allowed_units is None else [unit for unit in ORDER if unit in allowed_units]
	active_lookup = set(active_units)
	last_rate = 0.0
	guard = 0
	while gold > 0 and recruits_left > 0 and guard < 500:
		guard += 1
		effective_weights = {}
		min_cost = None
		for unit in ORDER:
			unit_cost = UNITS[unit]
			if unit not in active_lookup:
				w = 0.0
			elif wood <= 0 and unit_cost["wood"] > 0:
				w = 0.0
			elif iron <= 0 and unit_cost["iron"] > 0:
				w = 0.0
			else:
				w = weights.get(unit, 0.0)
			effective_weights[unit] = w
			if w > 0.0:
				if min_cost is None or unit_cost["gold"] < min_cost:
					min_cost = unit_cost["gold"]
		if min_cost is None or gold < min_cost:
			break
		weighted_sum = 0.0
		for unit in ORDER:
			weighted_sum += effective_weights[unit] * UNITS[unit]["gold"]
		if weighted_sum <= 0.0:
			break
		rate = gold / weighted_sum
		last_rate = rate
		loop_counts = {unit: int(math.floor(effective_weights[unit] * rate)) for unit in ORDER}
		if sum(loop_counts.values()) == 0:
			best_unit = max(active_units, key=lambda u: effective_weights[u])
			if effective_weights[best_unit] > 0.0 and gold >= UNITS[best_unit]["gold"] and wood >= UNITS[best_unit]["wood"] and iron >= UNITS[best_unit]["iron"]:
				loop_counts[best_unit] = 1
		if sum(loop_counts.values()) == 0:
			break
		total_loop = sum(loop_counts.values())
		if total_loop > recruits_left:
			scale = recruits_left / float(total_loop)
			for unit in ORDER:
				loop_counts[unit] = int(math.floor(loop_counts[unit] * scale))
			total_loop = sum(loop_counts.values())
			while total_loop > recruits_left:
				for unit in reversed(ORDER):
					if loop_counts[unit] > 0:
						loop_counts[unit] -= 1
						total_loop -= 1
						if total_loop <= recruits_left:
							break
		wood_used = sum(loop_counts[u] * UNITS[u]["wood"] for u in ORDER)
		iron_used = sum(loop_counts[u] * UNITS[u]["iron"] for u in ORDER)
		while wood_used > wood:
			removed = False
			for unit in ORDER:
				if UNITS[unit]["wood"] > 0 and loop_counts[unit] > 0:
					loop_counts[unit] -= 1
					wood_used -= UNITS[unit]["wood"]
					removed = True
					break
			if not removed:
				break
		while iron_used > iron:
			removed = False
			for unit in reversed(ORDER):
				if UNITS[unit]["iron"] > 0 and loop_counts[unit] > 0:
					loop_counts[unit] -= 1
					iron_used -= UNITS[unit]["iron"]
					removed = True
					break
			if not removed:
				break
			total_loop = sum(loop_counts.values())
			if total_loop <= 0:
				best_unit = max(active_units, key=lambda u: effective_weights[u])
				if (
					effective_weights[best_unit] > 0.0 and
					recruits_left > 0 and
					gold >= UNITS[best_unit]["gold"] and
					wood >= UNITS[best_unit]["wood"] and
					iron >= UNITS[best_unit]["iron"]
				):
					loop_counts[best_unit] = 1
					total_loop = 1
					wood_used = sum(loop_counts[u] * UNITS[u]["wood"] for u in ORDER)
					iron_used = sum(loop_counts[u] * UNITS[u]["iron"] for u in ORDER)
				else:
					break
		gold_spent = sum(loop_counts[u] * UNITS[u]["gold"] for u in ORDER)
		wood -= wood_used
		iron -= iron_used
		gold -= gold_spent
		recruits_left -= total_loop
		for unit in ORDER:
			counts[unit] += loop_counts[unit]
	spent_g = budgets["gold"] - gold
	spent_w = budgets["wood"] - wood
	spent_i = budgets["iron"] - iron
	left = (gold, wood, iron)
	spent = (spent_g, spent_w, spent_i)
	return counts, spent, left, last_rate

def compute_plan(
	gold: int,
	recruits: int,
	wood: int,
	iron: int,
	tier_cap: int,
	grassland_global: int,
	grassland_frontier: int
) -> dict:
	budgets = {
		"gold": max(0, gold),
		"wood": max(0, wood),
		"iron": max(0, iron),
	}
	shift = compute_shift(gold, recruits)
	horsemen_share = compute_horsemen_share(grassland_global, grassland_frontier)
	rng = random.Random()
	base_weights = build_base_weights(shift)
	weights = split_cavalry_weights(base_weights, horsemen_share)
	weights = add_ranged_weights(weights, rng)
	weights = apply_tier_mask(weights, tier_cap)
	shares = normalize_weights(weights)
	total_recruits = max(0, recruits)
	if total_recruits <= 0 or sum(shares.values()) <= 0.0:
		counts = {unit: 0 for unit in ORDER}
		return {
			"weights": weights,
			"shares": shares,
			"counts": counts,
			"spent": (0, 0, 0),
			"left": (budgets["gold"], budgets["wood"], budgets["iron"]),
			"requested_recruits": total_recruits,
			"assigned_recruits": 0,
			"rate": 0.0,
			"budgets": budgets,
			"mu_shift": shift,
			"horsemen_percentage": horsemen_share * 100.0,
				"ranged_assigned": 0,
				"ranged_percentage": 0.0,
				"tier_cap": tier_cap,
				"grassland_global": grassland_global,
				"grassland_frontier": grassland_frontier,
			}
	best_plan = choose_best_two_pass_plan(total_recruits, weights, budgets)
	counts = best_plan["counts"]
	spent = best_plan["spent"]
	left = best_plan["left"]
	rate = float(best_plan["rate"])
	final_recruits = int(best_plan["final_recruits"])
	ranged_assigned = int(best_plan["ranged_assigned"])
	ranged_percentage = float(best_plan["share_ratio"]) * 100.0
	return {
		"weights": weights,
		"shares": shares,
		"counts": counts,
		"spent": spent,
		"left": left,
		"requested_recruits": total_recruits,
		"assigned_recruits": final_recruits,
		"rate": rate,
		"budgets": budgets,
		"mu_shift": shift,
		"horsemen_percentage": horsemen_share * 100.0,
		"ranged_assigned": ranged_assigned,
		"ranged_percentage": ranged_percentage,
		"tier_cap": tier_cap,
		"grassland_global": grassland_global,
		"grassland_frontier": grassland_frontier,
	}

class App(tk.Tk):
	def __init__(self):
		super().__init__()
		self.title("Gaussian Recruitment Sandbox")
		self.geometry("1200x860")
		self.tier_selected = 5
		self._build()

	def _build(self) -> None:
		main = ttk.Frame(self, padding=10)
		main.pack(fill="both", expand=True)
		left = ttk.Frame(main)
		left.pack(side="left", fill="both", expand=True)
		right = ttk.Frame(main)
		right.pack(side="right", fill="both", expand=True)
		inp = ttk.LabelFrame(left, text="Inputs", padding=10)
		inp.pack(fill="x")
		self.gold_var = tk.StringVar(value="92")
		self.recruits_var = tk.StringVar(value="24")
		self.wood_var = tk.StringVar(value="12")
		self.iron_var = tk.StringVar(value="4")
		self.grassland_global_var = tk.StringVar(value="50")
		self.grassland_frontier_var = tk.StringVar(value="50")
		self.tier_var = tk.StringVar(value="5")
		row = 0
		self._add_input(inp, "Gold", self.gold_var, row)
		row += 1
		self._add_input(inp, "Recruits", self.recruits_var, row)
		row += 1
		self._add_input(inp, "Wood", self.wood_var, row)
		row += 1
		self._add_input(inp, "Iron", self.iron_var, row)
		row += 1
		self._add_input(inp, "Grassland Global %", self.grassland_global_var, row)
		row += 1
		self._add_input(inp, "Grassland Frontier %", self.grassland_frontier_var, row)
		row += 1
		self._add_input(inp, "Tier (1-5)", self.tier_var, row)
		row += 1
		ttk.Button(inp, text="Compute", command=self.compute).grid(
			row=row, column=0, columnspan=2, sticky="ew", pady=6
		)
		row += 1
		ttk.Button(inp, text="Select Tier", command=self._select_tier).grid(
			row=row, column=0, columnspan=2, sticky="ew", pady=4
		)
		bottom = ttk.Frame(left)
		bottom.pack(fill="both", expand=True, pady=(10, 0))
		ideal_frame = ttk.LabelFrame(bottom, text="Gaussian Weights (Ideal)", padding=8)
		ideal_frame.pack(side="left", fill="both", expand=True, padx=(0, 5))
		self.ideal_txt = tk.Text(ideal_frame, height=18, width=42)
		self.ideal_txt.pack(fill="both", expand=True)
		self.ideal_txt.configure(state="disabled")
		graph_frame = ttk.LabelFrame(bottom, text="Boosts replaced by Gaussian Curve", padding=8)
		graph_frame.pack(side="right", fill="both", expand=True, padx=(5, 0))
		self.graph_canvas = tk.Canvas(
			graph_frame,
			width=GRAPH_WIDTH,
			height=GRAPH_HEIGHT,
			background="#11151c",
			highlightthickness=0
		)
		self.graph_canvas.pack(fill="both", expand=True)
		out = ttk.LabelFrame(right, text="Output", padding=10)
		out.pack(fill="both", expand=True)
		self.out_txt = tk.Text(out, height=64, width=70)
		self.out_txt.pack(fill="both", expand=True)
		self.compute()

	def _add_input(self, parent: ttk.LabelFrame, label: str, var: tk.StringVar, row: int) -> None:
		ttk.Label(parent, text=label).grid(row=row, column=0, sticky="w", padx=4, pady=3)
		ttk.Entry(parent, textvariable=var, width=14).grid(row=row, column=1, sticky="w", padx=4, pady=3)

	def _render_weights(self, weights: Dict[str, float]) -> None:
		lines = [
			"Gaussian weights (mu shifts with gold/recruits).",
			"- mu = 0 at gold/recruits <= 0.5",
			"- mu = 4 at gold/recruits >= 5",
			"- weights drop to 0 when x >= 5",
			"- base gaussian buckets: peasants, spearmen, swordsmen, knights, royal_guard",
			"- horsemen split: swordsmen->(swordsmen+horsemen), knights->(knights+mounted_knights)",
			"- ranged target: 20-30% of recruited units when resources allow",
			"Values:",
		]
		for unit in ORDER:
			lines.append(f"{unit}: {weights.get(unit, 0.0):.2f}")
		content = "\n".join(lines)
		self.ideal_txt.configure(state="normal")
		self.ideal_txt.delete("1.0", "end")
		self.ideal_txt.insert("1.0", content)
		self.ideal_txt.configure(state="disabled")

	def _render_graph(self, weights: Dict[str, float]) -> None:
		canvas = self.graph_canvas
		canvas.delete("all")
		max_weight = max(weights.values()) if weights else 0.0
		if max_weight <= 0.0:
			max_weight = 1.0
		width = GRAPH_WIDTH
		height = GRAPH_HEIGHT
		margin = GRAPH_MARGIN
		canvas.create_rectangle(0, 0, width, height, fill="#11151c", outline="")
		canvas.create_line(margin, height - margin, width - margin, height - margin, fill="#6c7480")
		canvas.create_line(margin, margin, margin, height - margin, fill="#6c7480")
		points = []
		label_y = height - margin + 8
		for idx, unit in enumerate(ORDER):
			x_pos = margin + (idx / max(1, len(ORDER) - 1)) * (width - 2 * margin)
			y_pos = height - margin - (weights.get(unit, 0.0) / max_weight) * (height - 2 * margin)
			points.append((x_pos, y_pos))
			canvas.create_oval(x_pos - 3, y_pos - 3, x_pos + 3, y_pos + 3, fill="#f0b453", outline="")
			canvas.create_text(
				x_pos,
				label_y,
				text=unit.replace("_", "\n"),
				fill="#d8dee9",
				font=("TkDefaultFont", 8),
				anchor="n"
			)
		for idx in range(len(points) - 1):
			p1 = points[idx]
			p2 = points[idx + 1]
			canvas.create_line(p1[0], p1[1], p2[0], p2[1], fill="#d8572a", width=2)
		canvas.create_text(
			width - margin,
			margin,
			text="weight",
			fill="#d8dee9",
			anchor="ne",
			font=("TkDefaultFont", 8)
		)

	def _render_output(self, result: dict) -> None:
		counts = result["counts"]
		shares = result["shares"]
		spent_gold, spent_wood, spent_iron = result["spent"]
		left_gold, left_wood, left_iron = result["left"]
		lines = []
		lines.append("=== Inputs ===")
		lines.append(
			f"Gold: {result['budgets']['gold']} | Recruits requested: {result['requested_recruits']} | "
			f"Wood: {result['budgets']['wood']} | Iron: {result['budgets']['iron']}"
		)
		lines.append(
			f"Grassland Global %: {result['grassland_global']} | Grassland Frontier %: {result['grassland_frontier']}"
		)
		lines.append("")
		lines.append("=== Gaussian Profile ===")
		lines.append("Base x=0..4 maps peasants, spearmen, swordsmen, knights, royal_guard.")
		lines.append(f"mu shift from gold/recruits: {result['mu_shift']:.3f}")
		lines.append(f"Horsemen split share: {result['horsemen_percentage']:.1f}%")
		lines.append(f"Gold spend rate: {result['rate']:.3f}")
		lines.append(f"Tier cap: {result['tier_cap']}")
		lines.append("")
		lines.append("=== Composition ===")
		lines.append(f"Recruits assigned: {result['assigned_recruits']} / {result['requested_recruits']}")
		lines.append(f"Ranged assigned: {result['ranged_assigned']} ({result['ranged_percentage']:.1f}%)")
		lines.append(f"Spent -> gold {spent_gold}, wood {spent_wood}, iron {spent_iron}")
		lines.append(f"Left  -> gold {left_gold}, wood {left_wood}, iron {left_iron}")
		lines.append("")
		lines.append(f"{'unit':15s} {'weight':>8s} {'share':>8s} {'count':>7s} {'gold':>6s} {'wood':>6s} {'iron':>6s}")
		lines.append("-" * 62)
		for unit in ORDER:
			count = counts.get(unit, 0)
			costs = UNITS[unit]
			lines.append(
				f"{unit:15s} "
				f"{result['weights'].get(unit, 0.0):8.2f} "
				f"{shares.get(unit, 0.0):8.3f} "
				f"{count:7d} "
				f"{count * costs['gold']:6d} "
				f"{count * costs['wood']:6d} "
				f"{count * costs['iron']:6d}"
			)
		lines.append("-" * 62)
		self.out_txt.delete("1.0", "end")
		self.out_txt.insert("1.0", "\n".join(lines))

	def compute(self) -> None:
		try:
			gold = int(float(self.gold_var.get()))
			recruits = int(float(self.recruits_var.get()))
			wood = int(float(self.wood_var.get()))
			iron = int(float(self.iron_var.get()))
			grassland_global = int(float(self.grassland_global_var.get()))
			grassland_frontier = int(float(self.grassland_frontier_var.get()))
			tier = int(float(self.tier_var.get()))
		except ValueError as exc:
			messagebox.showerror("Error", f"Invalid number: {exc}")
			return
		if grassland_global < 0 or grassland_global > 100:
			messagebox.showerror("Error", "Grassland Global % must be between 0 and 100.")
			return
		if grassland_frontier < 0 or grassland_frontier > 100:
			messagebox.showerror("Error", "Grassland Frontier % must be between 0 and 100.")
			return
		tier = max(1, min(5, tier))
		self.tier_selected = tier
		self.tier_var.set(str(tier))
		result = compute_plan(gold, recruits, wood, iron, tier, grassland_global, grassland_frontier)
		self._render_weights(result["weights"])
		self._render_graph(result["weights"])
		self._render_output(result)

	def _select_tier(self) -> None:
		try:
			tier = int(float(self.tier_var.get()))
		except ValueError:
			messagebox.showerror("Error", "Tier must be a number between 1 and 5.")
			return
		tier = max(1, min(5, tier))
		self.tier_selected = tier
		self.tier_var.set(str(tier))
		self.compute()

if __name__ == "__main__":
	App().mainloop()
