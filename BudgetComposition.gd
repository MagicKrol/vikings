extends RefCounted
class_name BudgetComposition

var gold: int
var wood: int
var iron: int

func _init(_gold: int = 0, _wood: int = 0, _iron: int = 0) -> void:
	gold = _gold
	wood = _wood
	iron = _iron

func clone() -> BudgetComposition:
	return BudgetComposition.new(gold, wood, iron)

func to_dict() -> Dictionary:
	return {"gold": gold, "wood": wood, "iron": iron}

func add(other: BudgetComposition) -> void:
	gold += other.gold
	wood += other.wood
	iron += other.iron

func can_afford(costs: Dictionary) -> bool:
	return gold >= int(costs.get("gold", 0)) \
		and wood >= int(costs.get("wood", 0)) \
		and iron >= int(costs.get("iron", 0))

func spend(costs: Dictionary) -> bool:
	var g: int = int(costs.get("gold", 0))
	var w: int = int(costs.get("wood", 0))
	var i: int = int(costs.get("iron", 0))
	if gold < g or wood < w or iron < i:
		return false
	gold -= g
	wood -= w
	iron -= i
	return true