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

func apply_to_runtime(map_generator: MapGenerator, region_manager: RegionManager, army_manager: ArmyManager, visual_manager: VisualManager, scenario: Dictionary, player_manager: PlayerManagerNode, difficulty_token: String = "all") -> void:
	# 1) Ensure map is generated from the scenario's map file (caller should set data_file_path prior to generation)
	# 2) Apply region deltas, ownership, castles, armies (single pass, order matters)
	var resolved_difficulty: String = _normalize_runtime_difficulty_token(difficulty_token)
	var garrison_composition_overrides: Dictionary = _resolve_garrison_override_map(scenario, resolved_difficulty)
	var army_composition_overrides: Dictionary = _resolve_army_override_map(scenario, resolved_difficulty)
	var effective_player_resources: Array = _resolve_player_resources_for_difficulty(scenario, resolved_difficulty)
	var region_visual_refresh_ids: Array[int] = _apply_region_deltas(map_generator, region_manager, scenario, garrison_composition_overrides)
	_apply_ownership(map_generator, region_manager, scenario)
	_apply_castles(map_generator, visual_manager, scenario)
	_apply_armies(map_generator, army_manager, scenario, army_composition_overrides)
	_apply_player_resources(player_manager, effective_player_resources)
	_refresh_region_runtime_after_deltas(map_generator, region_visual_refresh_ids)

func _normalize_runtime_difficulty_token(raw_token: String) -> String:
	var normalized: String = raw_token.to_lower().strip_edges()
	match normalized:
		"easy", "normal", "hard":
			return normalized
		_:
			return "all"

func _get_difficulty_override_block(scenario: Dictionary, difficulty_token: String) -> Dictionary:
	if difficulty_token == "all":
		return {}
	var raw_overrides: Variant = scenario.get("difficulty_overrides", {})
	if not (raw_overrides is Dictionary):
		return {}
	var overrides: Dictionary = raw_overrides as Dictionary
	var raw_block: Variant = overrides.get(difficulty_token, {})
	if raw_block is Dictionary:
		return raw_block as Dictionary
	return {}

func _resolve_player_resources_for_difficulty(scenario: Dictionary, difficulty_token: String) -> Array:
	var raw_baseline: Variant = scenario.get("player_resources", [])
	var baseline_resources: Array = []
	if raw_baseline is Array:
		baseline_resources = raw_baseline as Array
	if difficulty_token == "all":
		return baseline_resources
	var block: Dictionary = _get_difficulty_override_block(scenario, difficulty_token)
	var raw_override: Variant = block.get("player_resources", null)
	if raw_override is Array:
		return raw_override as Array
	return baseline_resources

func _resolve_army_override_map(scenario: Dictionary, difficulty_token: String) -> Dictionary:
	return _resolve_composition_override_map(scenario, difficulty_token, "army_compositions")

func _resolve_garrison_override_map(scenario: Dictionary, difficulty_token: String) -> Dictionary:
	return _resolve_composition_override_map(scenario, difficulty_token, "garrison_compositions")

func _resolve_composition_override_map(scenario: Dictionary, difficulty_token: String, key_name: String) -> Dictionary:
	var block: Dictionary = _get_difficulty_override_block(scenario, difficulty_token)
	var raw_entries: Variant = block.get(key_name, [])
	if not (raw_entries is Array):
		return {}
	var entries: Array = raw_entries as Array
	var result: Dictionary = {}
	for raw_entry in entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry as Dictionary
		var region_id: int = int(entry.get("region_id", -1))
		if region_id <= 0:
			continue
		var raw_composition: Variant = entry.get("composition", {})
		if not (raw_composition is Dictionary):
			continue
		result[region_id] = _sanitize_unit_composition(raw_composition as Dictionary)
	return result

func _sanitize_unit_composition(raw_composition: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	for unit_type in SoldierTypeEnum.get_all_types():
		var unit_key: String = SoldierTypeEnum.type_to_string(unit_type)
		sanitized[unit_key] = maxi(0, int(raw_composition.get(unit_key, 0)))
	return sanitized

# Internal helpers -------------------------------------------------------------

func _apply_region_deltas(map_generator: MapGenerator, region_manager: RegionManager, scenario: Dictionary, garrison_composition_overrides: Dictionary) -> Array[int]:
	var region_visual_refresh_ids: Array[int] = []
	var regions: Array = scenario.get("regions", [])
	for r in regions:
		var region_id: int = int(r.get("id", -1))
		var region := map_generator.get_region_container_by_id(region_id) as Region
		var owner_id: int = int(r.get("owner", -1))
		var previous_biome: String = region.get_biome().to_lower()
		var previous_ocean: bool = region.is_ocean_region()
		region.set_scenario_ore_rules_enabled(true)
		var guaranteed_attempt: int = maxi(0, int(r.get("ore_guaranteed_discovery_attempt", 0)))
		var guaranteed_type_name: String = String(r.get("ore_guaranteed_discovery_type", "None"))
		if guaranteed_type_name.to_lower() == "none":
			guaranteed_attempt = 0
		var guaranteed_type: ResourcesEnum.Type = ResourcesEnum.string_to_type(guaranteed_type_name)
		region.set_ore_guaranteed_discovery(guaranteed_attempt, guaranteed_type)
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
		var current_biome: String = region.get_biome().to_lower()
		var current_ocean: bool = region.is_ocean_region()
		if previous_biome != current_biome or previous_ocean != current_ocean:
			_sync_map_region_runtime_data(map_generator, region_id, current_biome, current_ocean)
			region_visual_refresh_ids.append(region_id)
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
		var has_explicit_garrison: bool = r.has("garrison")
		if has_explicit_garrison:
			var gdict: Dictionary = r.get("garrison")
			var g := region.get_garrison()
			for t in SoldierTypeEnum.get_all_types():
				var key := SoldierTypeEnum.type_to_string(t)
				if gdict.has(key):
					g.set_soldier_count(t, int(gdict.get(key)))
		# Difficulty-specific garrison composition override
		var has_garrison_override: bool = garrison_composition_overrides.has(region_id)
		if has_garrison_override:
			var raw_override: Variant = garrison_composition_overrides.get(region_id, {})
			if raw_override is Dictionary:
				var override_composition: Dictionary = raw_override as Dictionary
				var garrison = region.get_garrison()
				for t in SoldierTypeEnum.get_all_types():
					var key := SoldierTypeEnum.type_to_string(t)
					if override_composition.has(key):
						garrison.set_soldier_count(t, int(override_composition.get(key)))
		if owner_id > 0 and not has_explicit_garrison and not has_garrison_override:
			_clear_region_garrison(region)
	return region_visual_refresh_ids

func _clear_region_garrison(region: Region) -> void:
	var garrison: ArmyComposition = region.get_garrison()
	for unit_type in SoldierTypeEnum.get_all_types():
		garrison.set_soldier_count(unit_type, 0)

func _sync_map_region_runtime_data(map_generator: MapGenerator, region_id: int, biome: String, is_ocean: bool) -> void:
	if map_generator.region_by_id.has(region_id):
		var region_data: Dictionary = map_generator.region_by_id[region_id]
		region_data["biome"] = biome
		region_data["ocean"] = is_ocean
		map_generator.region_by_id[region_id] = region_data
	for i in range(map_generator.regions.size()):
		var entry: Dictionary = map_generator.regions[i]
		if int(entry.get("id", -1)) != region_id:
			continue
		entry["biome"] = biome
		entry["ocean"] = is_ocean
		map_generator.regions[i] = entry
		break

func _refresh_region_runtime_after_deltas(map_generator: MapGenerator, region_ids: Array[int]) -> void:
	if region_ids.is_empty():
		return
	var unique_region_ids: Dictionary = {}
	for raw_region_id in region_ids:
		var region_id: int = int(raw_region_id)
		if region_id <= 0 or unique_region_ids.has(region_id):
			continue
		unique_region_ids[region_id] = true
		map_generator.refresh_region_visual(region_id)
	map_generator._build_non_ocean_graph_data()
	map_generator._compute_nearby_regions_for_all_land(2)

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
						var map_visual_scale := map_generator.get_map_visual_scale()
						castle_scale = castle_scale * map_generator.polygon_scale * map_visual_scale
						var polygon := container.get_node_or_null("Polygon") as Polygon2D
						if polygon != null and polygon.has_meta("center"):
							var center: Vector2 = polygon.get_meta("center")
							castle.position = center + Vector2(-5 * map_visual_scale, -5 * map_visual_scale)
						castle.scale = Vector2(castle_scale, castle_scale)
						castle.z_index = 100
						container.add_child(castle)

func _apply_armies(map_generator: MapGenerator, army_manager: ArmyManager, scenario: Dictionary, army_composition_overrides: Dictionary) -> void:
	var armies: Array = scenario.get("armies", [])
	for a in armies:
		var region_id: int = int(a.get("region_id", -1))
		var player_id: int = int(a.get("player_id", 1))
		var region := map_generator.get_region_container_by_id(region_id)
		var army := army_manager.create_army(region, player_id)
		if army == null:
			continue
		if a.has("name"):
			army.name = String(a.get("name"))
		if a.has("composition"):
			var comp: Dictionary = a.get("composition")
			for t in SoldierTypeEnum.get_all_types():
				var key := SoldierTypeEnum.type_to_string(t)
				if comp.has(key):
					army.get_composition().set_soldier_count(t, int(comp.get(key)))
		if army_composition_overrides.has(region_id):
			var raw_override: Variant = army_composition_overrides.get(region_id, {})
			if raw_override is Dictionary:
				var override_composition: Dictionary = raw_override as Dictionary
				for t in SoldierTypeEnum.get_all_types():
					var key := SoldierTypeEnum.type_to_string(t)
					if override_composition.has(key):
						army.get_composition().set_soldier_count(t, int(override_composition.get(key)))

func _apply_player_resources(player_manager: PlayerManagerNode, entries: Array) -> void:
	for entry in entries:
		if entry is Dictionary:
			var player_id := int(entry.get("player_id", 0))
			if player_id < 1 or player_id > player_manager.get_total_players():
				continue
			var resources: Dictionary = entry.get("resources", {})
			player_manager.set_player_resources(player_id, resources)
