extends RefCounted
class_name ScenarioManager

# =============================================================================
# SCENARIO MANAGER (Stage 1)
# =============================================================================
# Purpose: Load scenario JSON and provide simple, explicit application helpers.
#
# Scope (first stage):
# - Load scenario from path (JSON → Dictionary)
# - Apply scenario to runtime given explicit manager references
#   (MapGenerator, RegionManager, ArmyManager, VisualManager)
# - KISS helpers to apply regions, ownership, castles, and armies
#
# Integration (later stages):
# - GameManager hook to choose scenario vs custom mode
# - Optional editor hook to preview a scenario
# =============================================================================

# Public API ------------------------------------------------------------------

func load_scenario(path: String) -> Dictionary:
	# Always resolve to res://scenarios/<file>
	var scen_path := _resolve_scenario_path(path)
	var file := FileAccess.open(scen_path, FileAccess.READ)
	if file == null:
		DebugLogger.log("Scenario", "ERROR: Could not open scenario file: " + scen_path)
		return {}
	var txt := file.get_as_text()
	var json := JSON.new()
	var res := json.parse(txt)
	if res != OK:
		DebugLogger.log("Scenario", "ERROR: Failed to parse scenario JSON: " + json.error_string)
		return {}
	return json.data

func _resolve_scenario_path(name: String) -> String:
	if name == null or name == "":
		return "res://scenarios/scenario.json"
	if name.begins_with("res://"):
		return "res://scenarios/" + name.get_file()
	return "res://scenarios/" + name.get_file()

func apply_to_runtime(map_generator: MapGenerator, region_manager: RegionManager, army_manager: ArmyManager, visual_manager: VisualManager, scenario: Dictionary, player_manager: PlayerManagerNode) -> void:
	# 1) Ensure map is generated from the scenario's map file (caller should set data_file_path prior to generation)
	# 2) Apply region deltas, ownership, castles, armies (single pass, order matters)
	_apply_region_deltas(map_generator, region_manager, scenario)
	_apply_ownership(map_generator, region_manager, scenario)
	_apply_castles(map_generator, visual_manager, scenario)
	_apply_armies(map_generator, army_manager, scenario)
	_apply_player_resources(player_manager, scenario)

# Internal helpers -------------------------------------------------------------

func _apply_region_deltas(map_generator: MapGenerator, region_manager: RegionManager, scenario: Dictionary) -> void:
	var regions: Array = scenario.get("regions", [])
	for r in regions:
		var region_id: int = int(r.get("id", -1))
		var region := map_generator.get_region_container_by_id(region_id) as Region
		# Name: assign only if non-empty; otherwise generate for non-ocean regions
		if r.has("name"):
			var nm := String(r.get("name")).strip_edges()
			if nm != "":
				region.set_region_name(nm)
			else:
				if not region.is_ocean_region():
					region.set_region_name(region_manager.assign_region_name(region))
		# Type / Ocean
		if r.has("ocean") and bool(r.get("ocean")):
			region.set_ocean(true)
		else:
			if r.has("biome"):
				var biome: String = String(r.get("biome"))
				region.set_region_type(RegionTypeEnum.string_to_type(biome))
			region.set_ocean(false)
		# Level
		if r.has("level"):
			var lv = RegionLevelEnum.string_to_level(String(r.get("level")))
			region.set_region_level(lv)
			# Population
			if r.has("population"):
				region.set_population(int(r.get("population")))
				region.fill_recruits_to_maximum()
		# Resources
		if r.has("resources"):
			var res: Dictionary = r.get("resources")
			region.set_resources_from_dict(res)
		# Discovered ores
		if r.has("discovered_ores"):
			var ores_arr: Array = r.get("discovered_ores")
			var new_ores: Array[ResourcesEnum.Type] = []
			for ore_name in ores_arr:
				new_ores.append(ResourcesEnum.string_to_type(String(ore_name)))
			region.discovered_ores = new_ores
		# Garrison (optional)
		if r.has("garrison"):
			var gdict: Dictionary = r.get("garrison")
			var g := region.get_garrison()
			for t in SoldierTypeEnum.get_all_types():
				var key := SoldierTypeEnum.type_to_string(t)
				if gdict.has(key):
					g.set_soldier_count(t, int(gdict.get(key)))

func _apply_ownership(map_generator: MapGenerator, region_manager: RegionManager, scenario: Dictionary) -> void:
	var regions: Array = scenario.get("regions", [])
	for r in regions:
		var region_id: int = int(r.get("id", -1))
		if r.has("owner"):
			var owner_id: int = int(r.get("owner"))
			if owner_id > 0:
				region_manager.set_initial_region_ownership(region_id, owner_id)
			else:
				region_manager.set_region_ownership(region_id, owner_id)

func _apply_castles(map_generator: MapGenerator, visual_manager: VisualManager, scenario: Dictionary) -> void:
	var regions: Array = scenario.get("regions", [])
	for r in regions:
		var region_id: int = int(r.get("id", -1))
		if r.has("castle_type"):
			var ct = CastleTypeEnum.string_to_type(String(r.get("castle_type")))
			var region := map_generator.get_region_container_by_id(region_id) as Region
			region.set_castle_type(ct)
			region.fill_recruits_to_maximum()
			if ct != CastleTypeEnum.Type.NONE:
				if visual_manager != null:
					visual_manager.place_castle_visual(region)
				else:
					# Minimal visual placement for editor mode (no VisualManager in editor)
					var container = region as Node
					# Remove existing castle if any
					var existing = container.get_node_or_null("Castle")
					if existing:
						container.remove_child(existing)
						existing.queue_free()
					# Create icon
					var icon_path = CastleTypeEnum.get_icon_path(ct)
					if icon_path != "":
						var castle := Sprite2D.new()
						castle.name = "Castle"
						castle.texture = load(icon_path)
						var castle_scale := 0.12
						var map_size_scale := Utils.get_map_size_icon_scale(map_generator.map_size)
						castle_scale = castle_scale * map_generator.polygon_scale * map_size_scale
						var polygon := container.get_node_or_null("Polygon") as Polygon2D
						if polygon != null and polygon.has_meta("center"):
							var center: Vector2 = polygon.get_meta("center")
							castle.position = center + Vector2(-5 * map_size_scale, -5 * map_size_scale)
						castle.scale = Vector2(castle_scale, castle_scale)
						castle.z_index = 100
						container.add_child(castle)

func _apply_armies(map_generator: MapGenerator, army_manager: ArmyManager, scenario: Dictionary) -> void:
	var armies: Array = scenario.get("armies", [])
	for a in armies:
		var region_id: int = int(a.get("region_id", -1))
		var player_id: int = int(a.get("player_id", 1))
		var region := map_generator.get_region_container_by_id(region_id)
		var army := army_manager.create_army(region, player_id)
		if a.has("name"):
			army.name = String(a.get("name"))
		if a.has("composition"):
			var comp: Dictionary = a.get("composition")
			for t in SoldierTypeEnum.get_all_types():
				var key := SoldierTypeEnum.type_to_string(t)
				if comp.has(key):
					army.get_composition().set_soldier_count(t, int(comp.get(key)))

func _apply_player_resources(player_manager: PlayerManagerNode, scenario: Dictionary) -> void:
	if not scenario.has("player_resources"):
		return
	var entries: Array = scenario["player_resources"]
	for entry in entries:
		if entry is Dictionary:
			var player_id := int(entry.get("player_id", 0))
			if player_id < 1 or player_id > player_manager.get_total_players():
				continue
			var resources: Dictionary = entry.get("resources", {})
			player_manager.set_player_resources(player_id, resources)
