extends Node

const HEARTBEAT_SEC := 30.0
const ENDPOINT := "https://iking.dbox.pl/heartbeat/index.php"

var http := HTTPRequest.new()
var user_id := ""
var session_id := ""
var t := 0.0

func _ready() -> void:
	add_child(http)
	http.request_completed.connect(_on_http_done)

	user_id = _load_or_create_user_id()
	session_id = _uuid()

	_send_init()
	set_process(true)

func _process(delta: float) -> void:
	t += delta
	if t >= HEARTBEAT_SEC:
		t -= HEARTBEAT_SEC
		_send_tick()

func _notification(what: int) -> void:
	# Spróbuj dopisać "resztę" zanim user zamknie tab/okno.
	# W Web to nie jest gwarantowane, ale często działa.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_send_partial_and_reset()

func _send_init() -> void:
	_post({
		"action": "init",
		"user_id": user_id,
		"session_id": session_id,
		"ts": int(Time.get_unix_time_from_system()),
		"build": ProjectSettings.get_setting("application/config/version", "dev"),
		"platform": OS.get_name()
	})

func _send_tick() -> void:
	_post({
		"action": "tick",
		"user_id": user_id,
		"session_id": session_id,
		"seconds": int(HEARTBEAT_SEC),
		"ts": int(Time.get_unix_time_from_system()),
		"build": ProjectSettings.get_setting("application/config/version", "dev"),
		"platform": OS.get_name()
	})

func _send_partial_and_reset() -> void:
	if t < 0.5:
		return

	_post({
		"action": "partial",
		"user_id": user_id,
		"session_id": session_id,
		"seconds": int(round(t)),
		"ts": int(Time.get_unix_time_from_system()),
		"build": ProjectSettings.get_setting("application/config/version", "dev"),
		"platform": OS.get_name()
	})

	# żeby nie wysłać tego kilka razy (focus_out + close_request)
	t = 0.0

func _post(payload: Dictionary) -> void:
	var body := JSON.stringify(payload)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := http.request(ENDPOINT, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		# opcjonalnie: kolejka/retry
		pass

func _on_http_done(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	# Zostaw puste w prod. Na debug możesz odkomentować:
	# if response_code >= 400:
	#     print("HB error ", response_code, ": ", body.get_string_from_utf8())
	pass

func _load_or_create_user_id() -> String:
	var path := "user://analytics_user_id.txt"
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path).strip_edges()

	var id := _uuid()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(id)
	f.close()
	return id

func _uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		bytes[0],bytes[1],bytes[2],bytes[3],
		bytes[4],bytes[5],
		bytes[6],bytes[7],
		bytes[8],bytes[9],
		bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15],
	]
