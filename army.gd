extends Sprite2D
class_name Army

# Army properties - all data here
var player_id: int = 1
var movement_points: int = 5  # Default movement points per turn

# Army composition - soldiers in this army
var composition: ArmyComposition

func _init():
	# Set up the army sprite
	texture = load("res://images/warrior.png")
	scale = Vector2(0.07, 0.07)
	z_index = 125

func setup_army(new_player_id: int) -> void:
	"""Setup the army with player ID"""
	player_id = new_player_id
	movement_points = 5
	composition = ArmyComposition.new()
	
	# Start with a basic army composition
	composition.set_soldier_count(SoldierTypeEnum.Type.PEASANTS, 20)
	composition.set_soldier_count(SoldierTypeEnum.Type.KNIGHTS, 1)
	
	z_index = 125 + player_id

func reset_movement_points() -> void:
	"""Reset movement points for a new turn"""
	movement_points = 5

func spend_movement_points(cost: int) -> void:
	"""Spend movement points for a move"""
	movement_points -= cost

func get_player_id() -> int:
	"""Get the player ID"""
	return player_id

func get_movement_points() -> int:
	"""Get current movement points"""
	return movement_points

# Army composition methods
func get_composition() -> ArmyComposition:
	"""Get the army composition"""
	return composition

func get_soldier_count(soldier_type: SoldierTypeEnum.Type) -> int:
	"""Get count of specific soldier type"""
	return composition.get_soldier_count(soldier_type)

func add_soldiers(soldier_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Add soldiers to the army"""
	composition.add_soldiers(soldier_type, count)

func remove_soldiers(soldier_type: SoldierTypeEnum.Type, count: int) -> void:
	"""Remove soldiers from the army"""
	composition.remove_soldiers(soldier_type, count)

func get_total_soldiers() -> int:
	"""Get total number of soldiers in the army"""
	return composition.get_total_soldiers()

func get_army_strength() -> int:
	"""Get total combat strength of the army"""
	return composition.get_total_attack()

func get_army_composition_string() -> String:
	"""Get army composition as a readable string"""
	return composition.get_composition_string()
