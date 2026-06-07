<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
	http_response_code(204);
	exit;
}

$raw = file_get_contents('php://input');
$data = json_decode($raw, true);
if (!is_array($data)) {
	http_response_code(400);
	echo json_encode(['ok' => false, 'err' => 'bad_json']);
	exit;
}

$action = isset($data['action']) ? (string)$data['action'] : '';
$userId = isset($data['user_id']) ? (string)$data['user_id'] : '';
$appSessionId = isset($data['session_id']) ? (string)$data['session_id'] : '';
$seconds = isset($data['seconds']) ? (int)$data['seconds'] : 0;
$ts = isset($data['ts']) ? (int)$data['ts'] : time();
$build = isset($data['build']) ? (string)$data['build'] : '';
$platform = isset($data['platform']) ? (string)$data['platform'] : '';

if ($userId === '' || $appSessionId === '') {
	http_response_code(400);
	echo json_encode(['ok' => false, 'err' => 'missing_ids']);
	exit;
}

$dsn = "mysql:host=localhost;dbname=ikingdbo_heartbeat;charset=utf8mb4";
$dbUser = "ikingdbo_heartbeat";
$dbPass = "ajioshugjdvbmajnk";
$pdo = new PDO($dsn, $dbUser, $dbPass, [
	PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
	PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
]);

function insert_event(PDO $pdo, array $data, string $raw): void {
	$sql = "INSERT INTO analytics_events (
			event_ts, event_name, user_id, app_session_id, run_id,
			content_type, content_id, difficulty, elapsed_seconds,
			turn_count, outcome, payload_json
		) VALUES (
			:ts, :event_name, :user_id, :app_session_id, :run_id,
			:content_type, :content_id, :difficulty, :elapsed_seconds,
			:turn_count, :outcome, :payload_json
		)";
	$stmt = $pdo->prepare($sql);
	$stmt->execute([
		':ts' => (int)($data['ts'] ?? time()),
		':event_name' => (string)($data['action'] ?? ''),
		':user_id' => (string)($data['user_id'] ?? ''),
		':app_session_id' => (string)($data['session_id'] ?? ''),
		':run_id' => isset($data['run_id']) ? (string)$data['run_id'] : null,
		':content_type' => (string)($data['content_type'] ?? ''),
		':content_id' => (string)($data['content_id'] ?? ''),
		':difficulty' => (string)($data['difficulty'] ?? ''),
		':elapsed_seconds' => max(0, (int)($data['elapsed_seconds'] ?? 0)),
		':turn_count' => max(0, (int)($data['turn_count'] ?? 0)),
		':outcome' => (string)($data['outcome'] ?? ''),
		':payload_json' => $raw,
	]);
}

function upsert_run(PDO $pdo, array $data, string $status): void {
	$runId = isset($data['run_id']) ? (string)$data['run_id'] : '';
	if ($runId === '') {
		throw new RuntimeException('missing_run_id');
	}

		$sql = "INSERT INTO analytics_runs (
				run_id, user_id, app_session_id, content_type, content_id,
				difficulty, game_mode, map_file, scenario_path, victory_condition,
				status, started_ts, last_event_ts, elapsed_seconds, turn_count,
				winner_player_id, outcome_reason, build, platform,
				is_internal, run_source, internal_reason
			) VALUES (
				:run_id, :user_id, :app_session_id, :content_type, :content_id,
				:difficulty, :game_mode, :map_file, :scenario_path, :victory_condition,
				:status, :started_ts, :last_event_ts, :elapsed_seconds, :turn_count,
				:winner_player_id, :outcome_reason, :build, :platform,
				:is_internal, :run_source, :internal_reason
			)
			ON DUPLICATE KEY UPDATE
				last_event_ts = GREATEST(last_event_ts, VALUES(last_event_ts)),
				elapsed_seconds = GREATEST(elapsed_seconds, VALUES(elapsed_seconds)),
				turn_count = GREATEST(turn_count, VALUES(turn_count)),
				status = VALUES(status),
				winner_player_id = VALUES(winner_player_id),
				outcome_reason = VALUES(outcome_reason),
				build = VALUES(build),
				platform = VALUES(platform),
				is_internal = VALUES(is_internal),
				run_source = VALUES(run_source),
				internal_reason = VALUES(internal_reason)";
	$stmt = $pdo->prepare($sql);
	$stmt->execute([
		':run_id' => $runId,
		':user_id' => (string)$data['user_id'],
		':app_session_id' => (string)$data['session_id'],
		':content_type' => (string)($data['content_type'] ?? ''),
		':content_id' => (string)($data['content_id'] ?? ''),
		':difficulty' => (string)($data['difficulty'] ?? ''),
		':game_mode' => (string)($data['game_mode'] ?? ''),
		':map_file' => (string)($data['map_file'] ?? ''),
		':scenario_path' => (string)($data['scenario_path'] ?? ''),
		':victory_condition' => (string)($data['victory_condition'] ?? ''),
		':status' => $status,
		':started_ts' => (int)($data['started_ts'] ?? $data['ts'] ?? time()),
		':last_event_ts' => (int)($data['ts'] ?? time()),
		':elapsed_seconds' => max(0, (int)($data['elapsed_seconds'] ?? 0)),
		':turn_count' => max(0, (int)($data['turn_count'] ?? 0)),
		':winner_player_id' => isset($data['winner_player_id']) ? (int)$data['winner_player_id'] : null,
		':outcome_reason' => (string)($data['outcome_reason'] ?? ''),
		':build' => (string)($data['build'] ?? ''),
		':platform' => (string)($data['platform'] ?? ''),
		':is_internal' => !empty($data['is_internal']) ? 1 : 0,
		':run_source' => (string)($data['run_source'] ?? ''),
		':internal_reason' => (string)($data['internal_reason'] ?? ''),
	]);
}

try {
	if ($action === 'init') {
		$sql = "INSERT INTO play_sessions (user_id, session_id, total_seconds, last_tick, build, platform)
				VALUES (:u, :s, 0, :ts, :b, :p)
				ON DUPLICATE KEY UPDATE user_id = VALUES(user_id), build = VALUES(build), platform = VALUES(platform)";
		$stmt = $pdo->prepare($sql);
		$stmt->execute([':u' => $userId, ':s' => $appSessionId, ':ts' => $ts, ':b' => $build, ':p' => $platform]);
		insert_event($pdo, $data, $raw);
		echo json_encode(['ok' => true]);
		exit;
	}

	if ($action === 'tick' || $action === 'partial') {
		if ($seconds <= 0 || $seconds > 120) {
			http_response_code(400);
			echo json_encode(['ok' => false, 'err' => 'bad_seconds']);
			exit;
		}
		$sql = "UPDATE play_sessions
				SET total_seconds = total_seconds + :sec, last_tick = :ts
				WHERE session_id = :s AND :ts > last_tick";
		$stmt = $pdo->prepare($sql);
		$stmt->execute([':sec' => $seconds, ':ts' => $ts, ':s' => $appSessionId]);
		insert_event($pdo, $data, $raw);
		echo json_encode(['ok' => true, 'counted' => $stmt->rowCount()]);
		exit;
	}

	if ($action === 'run_start' || $action === 'run_heartbeat' || $action === 'run_finish' || $action === 'run_event') {
		insert_event($pdo, $data, $raw);
		if ($action === 'run_start') {
			upsert_run($pdo, $data, 'started');
		} elseif ($action === 'run_heartbeat') {
			upsert_run($pdo, $data, 'active');
		} elseif ($action === 'run_finish') {
			upsert_run($pdo, $data, (string)($data['outcome'] ?? 'finished'));
		}
		echo json_encode(['ok' => true]);
		exit;
	}

	http_response_code(400);
	echo json_encode(['ok' => false, 'err' => 'bad_action']);
} catch (Throwable $e) {
	http_response_code(500);
	echo json_encode(['ok' => false, 'err' => 'server_error']);
}
