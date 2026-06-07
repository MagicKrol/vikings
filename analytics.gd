extends Node

const HEARTBEAT_SEC: float = 30.0
const ENDPOINT: String = "https://iking.dbox.pl/heartbeat/heartbeat.php"
const INTERNAL_DEVICE_MARKER_PATH: String = "user://analytics_internal_device.txt"

var http: HTTPRequest = HTTPRequest.new()
var user_id: String = ""
var session_id: String = ""
var _app_heartbeat_elapsed: float = 0.0
var _request_queue: Array[Dictionary] = []
var _request_in_flight: bool = false
var _is_internal_device: bool = false
var _analytics_run_source: String = "export"
var _analytics_internal_reason: String = ""

var _run_active: bool = false
var _run_finished: bool = false
var _run_id: String = ""
var _run_content_type: String = ""
var _run_content_id: String = ""
var _run_difficulty: String = ""
var _run_game_mode: String = ""
var _run_map_file: String = ""
var _run_scenario_path: String = ""
var _run_victory_condition: String = ""
var _run_started_ts: int = 0
var _run_elapsed_seconds: float = 0.0
var _run_last_turn_count: int = 0

func _ready() -> void:
	add_child(http)
	http.request_completed.connect(_on_http_done)

	user_id = _load_or_create_user_id()
	session_id = _uuid()
	_initialize_internal_tracking_tags()

	_send_init()
	set_process(true)

func _process(delta: float) -> void:
	_app_heartbeat_elapsed += delta
	if _run_active and not _run_finished:
		_run_elapsed_seconds += delta

	if _app_heartbeat_elapsed >= HEARTBEAT_SEC:
		_app_heartbeat_elapsed -= HEARTBEAT_SEC
		_send_tick(int(HEARTBEAT_SEC))
		heartbeat_content_run(_run_last_turn_count)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		finish_content_run("quit", _run_last_turn_count, -1, "window_close")
		_send_partial_and_reset()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_send_partial_and_reset()
		heartbeat_content_run(_run_last_turn_count)

func start_content_run(content_type: String, content_id: String, difficulty: String, game_mode: String, map_file: String, scenario_path: String, victory_condition: String, turn_count: int) -> void:
	if _run_active and not _run_finished:
		finish_content_run("quit", _run_last_turn_count, -1, "new_run_started")

	_run_active = true
	_run_finished = false
	_run_id = _uuid()
	_run_content_type = content_type
	_run_content_id = content_id
	_run_difficulty = difficulty
	_run_game_mode = game_mode
	_run_map_file = map_file
	_run_scenario_path = scenario_path
	_run_victory_condition = victory_condition
	_run_started_ts = int(Time.get_unix_time_from_system())
	_run_elapsed_seconds = 0.0
	_run_last_turn_count = turn_count

	var payload: Dictionary = _build_run_payload("run_start")
	_enqueue_post(payload)

func heartbeat_content_run(turn_count: int) -> void:
	if not _run_active or _run_finished:
		return
	_run_last_turn_count = turn_count
	var payload: Dictionary = _build_run_payload("run_heartbeat")
	_enqueue_post(payload)

func finish_content_run(outcome: String, turn_count: int, winner_player_id: int = -1, outcome_reason: String = "") -> void:
	if not _run_active or _run_finished:
		return
	_run_last_turn_count = turn_count
	var payload: Dictionary = _build_run_payload("run_finish")
	payload["outcome"] = outcome
	payload["outcome_reason"] = outcome_reason
	if winner_player_id > 0:
		payload["winner_player_id"] = winner_player_id
	_enqueue_post(payload)
	_run_finished = true
	_run_active = false

func record_content_event(event_type: String, turn_count: int, extra_payload: Dictionary = {}) -> void:
	if not _run_active or _run_finished:
		return
	_run_last_turn_count = turn_count
	var payload: Dictionary = _build_run_payload("run_event")
	payload["event_type"] = event_type
	for key in extra_payload.keys():
		payload[key] = extra_payload[key]
	_enqueue_post(payload)

func set_content_run_turn_count(turn_count: int) -> void:
	_run_last_turn_count = turn_count

func get_content_run_for_save() -> Dictionary:
	if not _run_active or _run_finished:
		return {}
	return {
		"run_id": _run_id,
		"content_type": _run_content_type,
		"content_id": _run_content_id,
		"difficulty": _run_difficulty,
		"game_mode": _run_game_mode,
		"map_file": _run_map_file,
		"scenario_path": _run_scenario_path,
		"victory_condition": _run_victory_condition,
		"started_ts": _run_started_ts,
		"elapsed_seconds": int(round(_run_elapsed_seconds)),
		"turn_count": _run_last_turn_count
	}

func set_content_run_from_save(run_data: Dictionary) -> void:
	_run_id = String(run_data.get("run_id", ""))
	if _run_id == "":
		_clear_content_run()
		return
	_run_active = true
	_run_finished = false
	_run_content_type = String(run_data.get("content_type", ""))
	_run_content_id = String(run_data.get("content_id", ""))
	_run_difficulty = String(run_data.get("difficulty", ""))
	_run_game_mode = String(run_data.get("game_mode", ""))
	_run_map_file = String(run_data.get("map_file", ""))
	_run_scenario_path = String(run_data.get("scenario_path", ""))
	_run_victory_condition = String(run_data.get("victory_condition", ""))
	_run_started_ts = int(run_data.get("started_ts", Time.get_unix_time_from_system()))
	_run_elapsed_seconds = float(run_data.get("elapsed_seconds", 0))
	_run_last_turn_count = int(run_data.get("turn_count", 0))

func _clear_content_run() -> void:
	_run_active = false
	_run_finished = false
	_run_id = ""
	_run_content_type = ""
	_run_content_id = ""
	_run_difficulty = ""
	_run_game_mode = ""
	_run_map_file = ""
	_run_scenario_path = ""
	_run_victory_condition = ""
	_run_started_ts = 0
	_run_elapsed_seconds = 0.0
	_run_last_turn_count = 0

func _send_init() -> void:
	_enqueue_post(_build_base_payload("init"))

func _send_tick(seconds: int) -> void:
	var payload: Dictionary = _build_base_payload("tick")
	payload["seconds"] = seconds
	_enqueue_post(payload)

func _send_partial_and_reset() -> void:
	if _app_heartbeat_elapsed < 0.5:
		return

	var payload: Dictionary = _build_base_payload("partial")
	payload["seconds"] = int(round(_app_heartbeat_elapsed))
	_enqueue_post(payload)
	_app_heartbeat_elapsed = 0.0

func _build_base_payload(action: String) -> Dictionary:
	return {
		"action": action,
		"user_id": user_id,
		"session_id": session_id,
		"ts": int(Time.get_unix_time_from_system()),
		"build": String(ProjectSettings.get_setting("application/config/version", "dev")),
		"platform": OS.get_name(),
		"run_source": _analytics_run_source,
		"is_internal": _is_internal_device,
		"internal_reason": _analytics_internal_reason
	}

func _initialize_internal_tracking_tags() -> void:
	var internal_reasons: Array[String] = []
	if OS.has_feature("editor"):
		_analytics_run_source = "godot_editor"
		internal_reasons.append("godot_editor")
	else:
		_analytics_run_source = "export"
	if FileAccess.file_exists(INTERNAL_DEVICE_MARKER_PATH):
		internal_reasons.append("internal_device_marker")
	_is_internal_device = not internal_reasons.is_empty()
	_analytics_internal_reason = ",".join(internal_reasons)

func _build_run_payload(action: String) -> Dictionary:
	var payload: Dictionary = _build_base_payload(action)
	payload["run_id"] = _run_id
	payload["content_type"] = _run_content_type
	payload["content_id"] = _run_content_id
	payload["difficulty"] = _run_difficulty
	payload["game_mode"] = _run_game_mode
	payload["map_file"] = _run_map_file
	payload["scenario_path"] = _run_scenario_path
	payload["victory_condition"] = _run_victory_condition
	payload["started_ts"] = _run_started_ts
	payload["elapsed_seconds"] = int(round(_run_elapsed_seconds))
	payload["turn_count"] = _run_last_turn_count
	return payload

func _enqueue_post(payload: Dictionary) -> void:
	_request_queue.append(payload)
	_send_next_if_idle()

func _send_next_if_idle() -> void:
	if _request_in_flight:
		return
	if _request_queue.is_empty():
		return
	var payload: Dictionary = _request_queue[0]
	var body: String = JSON.stringify(payload)
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	var error: int = http.request(ENDPOINT, headers, HTTPClient.METHOD_POST, body)
	if error == OK:
		_request_in_flight = true
		return
	_request_queue.pop_front()
	_send_next_if_idle()

func _on_http_done(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if not _request_queue.is_empty():
		_request_queue.pop_front()
	_request_in_flight = false
	_send_next_if_idle()

func _load_or_create_user_id() -> String:
	var path: String = "user://analytics_user_id.txt"
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path).strip_edges()

	var id: String = _uuid()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(id)
	file.close()
	return id

func _uuid() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		bytes[0], bytes[1], bytes[2], bytes[3],
		bytes[4], bytes[5],
		bytes[6], bytes[7],
		bytes[8], bytes[9],
		bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15],
	]
