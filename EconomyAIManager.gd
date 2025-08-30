extends RefCounted
class_name EconomyAIManager

# Foundation for AI economy planning. KISS: keep recruitment wired, stub others.

var region_manager: RegionManager
var army_manager: ArmyManager
var player_manager: PlayerManagerNode
var budget_manager: BudgetManager

func _init(_region_manager: RegionManager, _army_manager: ArmyManager, _player_manager: PlayerManagerNode) -> void:
	region_manager = _region_manager
	army_manager = _army_manager
	player_manager = _player_manager
	budget_manager = BudgetManager.new()

# Public entry: plan and allocate budgets for this player's turn.
# Currently only recruitment is executed; other categories are stubs.
func plan_turn(player_id: int, turn_number: int) -> Dictionary:
	var signals = _compute_signals(player_id, turn_number)
	var weights = _score_categories(signals)
	var chosen = _pick_categories(weights)
	var result: Dictionary = {}
	if chosen.has("recruit"):
		result["recruit_assigned"] = _allocate_recruitment(player_id, turn_number)
	return result

# Signals summarize state. Stub for now to keep architecture ready.
func _compute_signals(player_id: int, turn_number: int) -> Dictionary:
	return {
		"frontier_pressure": 0.0,
		"army_power_gap": 0.0,
		"resource_scarcity": {},
		"recruit_abundance": 0.0,
		"castle_spacing": 0.0,
		"turn_index": float(turn_number)
	}

# Turn signals to weights per category. Stub: recruit always enabled.
func _score_categories(signals: Dictionary) -> Dictionary:
	return {
		"recruit": 1.0,
		"raise_army": 0.0,
		"region_upgrade": 0.0,
		"castle_upgrade": 0.0,
		"savings": 0.0
	}

# Pick active categories (weight > 0). Deterministic order.
func _pick_categories(weights: Dictionary) -> Array:
	var active: Array = []
	if float(weights.get("recruit", 0.0)) > 0.0:
		active.append("recruit")
	return active

# Delegate to existing BudgetManager to keep compatibility with recruitment flow.
func _allocate_recruitment(player_id: int, turn_number: int) -> int:
	var player = player_manager.get_player(player_id)
	var armies: Array[Army] = army_manager.get_player_armies(player_id)
	return budget_manager.allocate_recruitment_budgets(armies, player, region_manager, turn_number)

