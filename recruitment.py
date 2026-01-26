import math
import random
import tkinter as tk
from tkinter import ttk, messagebox
from typing import Dict, Tuple

UNITS = {
	"peasants": {"gold": 1, "wood": 0, "iron": 0},
	"spearmen": {"gold": 1, "wood": 0, "iron": 0},
	"swordsmen": {"gold": 3, "wood": 0, "iron": 0},
	"archers": {"gold": 4, "wood": 1, "iron": 0},
	"crossbowmen": {"gold": 4, "wood": 1, "iron": 0},
	"horsemen": {"gold": 5, "wood": 0, "iron": 0},
	"knights": {"gold": 10, "wood": 0, "iron": 1},
	"mounted_knights": {"gold": 15, "wood": 0, "iron": 1},
	"royal_guard": {"gold": 20, "wood": 0, "iron": 1},
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
	"horsemen",
	"knights",
	"mounted_knights",
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
WEIGHT_CUTOFF_X = 7.0
MIN_RATIO = 0.5
MAX_RATIO = 5.0
MAX_SHIFT = 6.0
RANGED_MIN_SHARE = 0.2
RANGED_MAX_SHARE = 0.3

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

def add_ranged_weights(base_weights: Dict[str, float], rng: random.Random) -> Dict[str, float]:
	weights = dict(base_weights)
	total_base = sum(base_weights.values())
	if total_base <= 0.0:
		weights["archers"] = 0.0
		weights["crossbowmen"] = 0.0
		return weights
	ranged_roll = rng.uniform(RANGED_MIN_SHARE, RANGED_MAX_SHARE)
	ranged_pool = total_base * ranged_roll
	archer_mass = base_weights.get("peasants", 0.0) + base_weights.get("spearmen", 0.0) + base_weights.get("swordsmen", 0.0)
	crossbow_mass = base_weights.get("horsemen", 0.0) + base_weights.get("knights", 0.0) + base_weights.get("mounted_knights", 0.0)
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

def purchase_units(weights: Dict[str, float], budgets: Dict[str, int], recruits: int) -> Tuple[Dict[str, int], Tuple[int, int, int], Tuple[int, int, int], float]:
	counts = {unit: 0 for unit in ORDER}
	gold = budgets["gold"]
	wood = budgets["wood"]
	iron = budgets["iron"]
	recruits_left = max(0, recruits)
	last_rate = 0.0
	guard = 0
	while gold > 0 and recruits_left > 0 and guard < 500:
		guard += 1
		effective_weights = {}
		min_cost = None
		for unit in ORDER:
			unit_cost = UNITS[unit]
			if wood <= 0 and unit_cost["wood"] > 0:
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
			best_unit = max(ORDER, key=lambda u: effective_weights[u])
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

def compute_plan(gold: int, recruits: int, wood: int, iron: int, tier_cap: int) -> dict:
	budgets = {
		"gold": max(0, gold),
		"wood": max(0, wood),
		"iron": max(0, iron),
	}
	shift = compute_shift(gold, recruits)
	rng = random.Random()
	base_weights = build_base_weights(shift)
	weights = add_ranged_weights(base_weights, rng)
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
			"tier_cap": tier_cap,
		}
	counts, spent, left, rate = purchase_units(weights, budgets, total_recruits)
	final_recruits = sum(counts.values())
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
		"tier_cap": tier_cap,
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
			"- mu = 6 at gold/recruits >= 5",
			"- weights drop to 0 when x >= 7",
			"- 20-30% of base weight is diverted to ranged (archers from x 0-2 mass, crossbowmen from x 3-5 mass)",
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
		lines.append("")
		lines.append("=== Gaussian Profile ===")
		lines.append("Base x=0..6 maps peasants -> royal_guard; ranged gets 20-30% of base weight (0-2 to archers, 3-5 to crossbowmen).")
		lines.append(f"mu shift from gold/recruits: {result['mu_shift']:.3f}")
		lines.append(f"Gold spend rate: {result['rate']:.3f}")
		lines.append(f"Tier cap: {result['tier_cap']}")
		lines.append("")
		lines.append("=== Composition ===")
		lines.append(f"Recruits assigned: {result['assigned_recruits']} / {result['requested_recruits']}")
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
			tier = int(float(self.tier_var.get()))
		except ValueError as exc:
			messagebox.showerror("Error", f"Invalid number: {exc}")
			return
		tier = max(1, min(5, tier))
		self.tier_selected = tier
		self.tier_var.set(str(tier))
		result = compute_plan(gold, recruits, wood, iron, tier)
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
