import express from "express";
import mysql from "mysql2/promise";
import path from "node:path";
import { fileURLToPath } from "node:url";
import dotenv from "dotenv";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, "..");
const distDir = path.join(rootDir, "dist");

dotenv.config({ path: path.join(rootDir, ".env") });

const app = express();
const port = Number(process.env.ANALYTICS_SERVER_PORT || process.env.PORT || 3005);

const pool = mysql.createPool({
	host: process.env.ANALYTICS_DB_HOST || "localhost",
	port: Number(process.env.ANALYTICS_DB_PORT || 3306),
	database: process.env.ANALYTICS_DB_NAME || "ikingdbo_heartbeat",
	user: process.env.ANALYTICS_DB_USER || "ikingdbo_heartbeat",
	password: process.env.ANALYTICS_DB_PASSWORD || "",
	waitForConnections: true,
	connectionLimit: 8,
	namedPlaceholders: true
});

const granularityFormats = {
	day: "%Y-%m-%d",
	week: "%x-W%v",
	month: "%Y-%m"
};

const excludedUserIds = String(process.env.ANALYTICS_EXCLUDED_USER_IDS || "")
	.split(",")
	.map((value) => value.trim())
	.filter((value) => value !== "");

function parseInteger(value, fallback) {
	const parsed = Number.parseInt(String(value ?? ""), 10);
	return Number.isFinite(parsed) ? parsed : fallback;
}

function normalizeFilters(query) {
	const nowSeconds = Math.floor(Date.now() / 1000);
	const defaultFrom = nowSeconds - 60 * 60 * 24 * 30;
	return {
		from: Math.max(0, parseInteger(query.from, defaultFrom)),
		to: Math.max(0, parseInteger(query.to, nowSeconds + 1)),
		contentType: String(query.contentType || ""),
		contentId: String(query.contentId || ""),
		difficulty: String(query.difficulty || ""),
		gameMode: String(query.gameMode || ""),
		status: String(query.status || ""),
		build: String(query.build || ""),
		platform: String(query.platform || ""),
		includeInternal: String(query.includeInternal || "false") === "true",
		granularity: granularityFormats[String(query.granularity || "day")] ? String(query.granularity || "day") : "day"
	};
}

function buildWhere(filters) {
	const clauses = ["started_ts >= :from", "started_ts < :to"];
	const params = { from: filters.from, to: filters.to };
	if (!filters.includeInternal) {
		clauses.push("is_internal = 0");
		addExcludedUsersClause(clauses, params, "user_id");
	}
	for (const key of ["contentType", "contentId", "difficulty", "gameMode", "status", "build", "platform"]) {
		if (filters[key] !== "") {
			const column = {
				contentType: "content_type",
				contentId: "content_id",
				difficulty: "difficulty",
				gameMode: "game_mode",
				status: "status",
				build: "build",
				platform: "platform"
			}[key];
			clauses.push(`${column} = :${key}`);
			params[key] = filters[key];
		}
	}
	return { sql: clauses.join(" AND "), params };
}

function buildEventWhere(filters) {
	const clauses = ["event_ts >= :from", "event_ts < :to"];
	const params = { from: filters.from, to: filters.to };
	if (!filters.includeInternal) {
		clauses.push("(JSON_UNQUOTE(JSON_EXTRACT(payload_json, '$.is_internal')) IS NULL OR JSON_UNQUOTE(JSON_EXTRACT(payload_json, '$.is_internal')) <> 'true')");
		addExcludedUsersClause(clauses, params, "user_id");
	}
	return { sql: clauses.join(" AND "), params };
}

function addExcludedUsersClause(clauses, params, columnName) {
	if (excludedUserIds.length === 0) {
		return;
	}
	const placeholders = excludedUserIds.map((userId, index) => {
		const key = `excludedUserId${index}`;
		params[key] = userId;
		return `:${key}`;
	});
	clauses.push(`${columnName} NOT IN (${placeholders.join(", ")})`);
}

async function queryRows(sql, params = {}) {
	const [rows] = await pool.execute(sql, params);
	return rows;
}

function asNumber(value) {
	return Number(value || 0);
}

function mapRate(numerator, denominator) {
	if (!denominator) {
		return 0;
	}
	return Math.round((Number(numerator || 0) / Number(denominator || 0)) * 1000) / 10;
}

app.get("/api/analytics", async (req, res) => {
	const filters = normalizeFilters(req.query);
	const where = buildWhere(filters);
	const eventWhere = buildEventWhere(filters);
	const periodFormat = granularityFormats[filters.granularity];

	try {
		const [summaryRows, timeSeries, contentRows, difficultyRows, durationRows, statusRows, platformRows, recentRuns, eventRows] = await Promise.all([
			queryRows(`
				SELECT
					COUNT(*) AS total_runs,
					COUNT(DISTINCT user_id) AS unique_players,
					SUM(status IN ('won', 'lost')) AS completed_runs,
					SUM(status = 'won') AS won_runs,
					SUM(status = 'lost') AS lost_runs,
					SUM(status = 'quit') AS quit_runs,
					SUM(status IN ('started', 'active')) AS open_runs,
					AVG(NULLIF(elapsed_seconds, 0)) AS avg_seconds,
					AVG(CASE WHEN status IN ('won', 'lost') THEN NULLIF(elapsed_seconds, 0) END) AS avg_completed_seconds,
					AVG(NULLIF(turn_count, 0)) AS avg_turns
				FROM analytics_runs
				WHERE ${where.sql}
			`, where.params),
			queryRows(`
				SELECT
					DATE_FORMAT(FROM_UNIXTIME(started_ts), '${periodFormat}') AS bucket,
					COUNT(*) AS total_runs,
					SUM(status IN ('won', 'lost')) AS completed_runs,
					SUM(status = 'won') AS won_runs,
					SUM(status = 'quit') AS quit_runs,
					AVG(NULLIF(elapsed_seconds, 0)) AS avg_seconds
				FROM analytics_runs
				WHERE ${where.sql}
				GROUP BY bucket
				ORDER BY MIN(started_ts)
			`, where.params),
			queryRows(`
				SELECT
					content_type,
					content_id,
					game_mode,
					COUNT(*) AS total_runs,
					COUNT(DISTINCT user_id) AS unique_players,
					SUM(status IN ('won', 'lost')) AS completed_runs,
					SUM(status = 'won') AS won_runs,
					SUM(status = 'lost') AS lost_runs,
					SUM(status = 'quit') AS quit_runs,
					AVG(NULLIF(elapsed_seconds, 0)) AS avg_seconds,
					AVG(NULLIF(turn_count, 0)) AS avg_turns,
					AVG(CASE WHEN status = 'won' THEN NULLIF(turn_count, 0) END) AS avg_win_turns,
					MIN(CASE WHEN status = 'won' THEN NULLIF(turn_count, 0) END) AS min_win_turns
				FROM analytics_runs
				WHERE ${where.sql}
				GROUP BY content_type, content_id, game_mode
				ORDER BY total_runs DESC, content_type, content_id
				LIMIT 40
			`, where.params),
			queryRows(`
				SELECT
					COALESCE(NULLIF(difficulty, ''), 'unknown') AS difficulty,
					COUNT(*) AS total_runs,
					SUM(status IN ('won', 'lost')) AS completed_runs,
					SUM(status = 'won') AS won_runs,
					SUM(status = 'quit') AS quit_runs,
					AVG(NULLIF(elapsed_seconds, 0)) AS avg_seconds
				FROM analytics_runs
				WHERE ${where.sql}
				GROUP BY COALESCE(NULLIF(difficulty, ''), 'unknown')
				ORDER BY total_runs DESC
			`, where.params),
			queryRows(`
				SELECT
					CASE
						WHEN elapsed_seconds < 300 THEN '<5m'
						WHEN elapsed_seconds < 900 THEN '5-15m'
						WHEN elapsed_seconds < 1800 THEN '15-30m'
						WHEN elapsed_seconds < 3600 THEN '30-60m'
						WHEN elapsed_seconds < 7200 THEN '1-2h'
						ELSE '2h+'
					END AS bucket,
					COUNT(*) AS total_runs
				FROM analytics_runs
				WHERE ${where.sql}
				GROUP BY bucket
				ORDER BY FIELD(bucket, '<5m', '5-15m', '15-30m', '30-60m', '1-2h', '2h+')
			`, where.params),
			queryRows(`
				SELECT status, COUNT(*) AS total_runs
				FROM analytics_runs
				WHERE ${where.sql}
				GROUP BY status
				ORDER BY total_runs DESC
			`, where.params),
			queryRows(`
				SELECT COALESCE(NULLIF(platform, ''), 'unknown') AS platform, COUNT(*) AS total_runs
				FROM analytics_runs
				WHERE ${where.sql}
				GROUP BY COALESCE(NULLIF(platform, ''), 'unknown')
				ORDER BY total_runs DESC
			`, where.params),
			queryRows(`
				SELECT
					run_id, user_id, content_type, content_id, difficulty, game_mode,
					status, started_ts, last_event_ts, elapsed_seconds, turn_count,
					platform, build, outcome_reason
				FROM analytics_runs
				WHERE ${where.sql}
				ORDER BY started_ts DESC
				LIMIT 80
			`, where.params),
			queryRows(`
				SELECT event_name, COUNT(*) AS total_events
				FROM analytics_events
				WHERE ${eventWhere.sql}
				GROUP BY event_name
				ORDER BY total_events DESC
			`, eventWhere.params)
		]);

		const summary = summaryRows[0] || {};
		const totalRuns = asNumber(summary.total_runs);
		res.json({
			filters,
			excludedUserCount: filters.includeInternal ? 0 : excludedUserIds.length,
			summary: {
				totalRuns,
				uniquePlayers: asNumber(summary.unique_players),
				completedRuns: asNumber(summary.completed_runs),
				wonRuns: asNumber(summary.won_runs),
				lostRuns: asNumber(summary.lost_runs),
				quitRuns: asNumber(summary.quit_runs),
				openRuns: asNumber(summary.open_runs),
				avgSeconds: asNumber(summary.avg_seconds),
				avgCompletedSeconds: asNumber(summary.avg_completed_seconds),
				avgTurns: asNumber(summary.avg_turns),
				finishRate: mapRate(summary.completed_runs, totalRuns),
				winRate: mapRate(summary.won_runs, summary.completed_runs),
				quitRate: mapRate(summary.quit_runs, totalRuns)
			},
			timeSeries,
			contentRows,
			difficultyRows,
			durationRows,
			statusRows,
			platformRows,
			recentRuns,
			eventRows
		});
	} catch (error) {
		res.status(500).json({
			error: "analytics_query_failed",
			message: error instanceof Error ? error.message : "Unknown database error"
		});
	}
});

app.get("/api/analytics/options", async (_req, res) => {
	try {
		const optionClauses = ["is_internal = 0"];
		const optionParams = {};
		addExcludedUsersClause(optionClauses, optionParams, "user_id");
		const optionWhere = optionClauses.join(" AND ");
		const [contentTypes, difficulties, gameModes, statuses, builds, platforms] = await Promise.all([
			queryRows(`SELECT DISTINCT content_type AS value FROM analytics_runs WHERE content_type <> '' AND ${optionWhere} ORDER BY content_type`, optionParams),
			queryRows(`SELECT DISTINCT difficulty AS value FROM analytics_runs WHERE difficulty <> '' AND ${optionWhere} ORDER BY difficulty`, optionParams),
			queryRows(`SELECT DISTINCT game_mode AS value FROM analytics_runs WHERE game_mode <> '' AND ${optionWhere} ORDER BY game_mode`, optionParams),
			queryRows(`SELECT DISTINCT status AS value FROM analytics_runs WHERE status <> '' AND ${optionWhere} ORDER BY status`, optionParams),
			queryRows(`SELECT DISTINCT build AS value FROM analytics_runs WHERE build <> '' AND ${optionWhere} ORDER BY build DESC LIMIT 40`, optionParams),
			queryRows(`SELECT DISTINCT platform AS value FROM analytics_runs WHERE platform <> '' AND ${optionWhere} ORDER BY platform`, optionParams)
		]);
		res.json({ contentTypes, difficulties, gameModes, statuses, builds, platforms });
	} catch (error) {
		res.status(500).json({
			error: "analytics_options_failed",
			message: error instanceof Error ? error.message : "Unknown database error"
		});
	}
});

app.use(express.static(distDir));
app.get("*", (_req, res) => {
	res.sendFile(path.join(distDir, "index.html"));
});

const server = app.listen(port, "127.0.0.1", () => {
	console.log(`Vikings analytics dashboard listening on http://127.0.0.1:${port}`);
});

server.on("error", (error) => {
	if (error.code === "EADDRINUSE") {
		console.error(`Port ${port} is already in use. Stop the existing dashboard process or open http://127.0.0.1:${port}.`);
		process.exit(1);
	}
	console.error(error.message);
	process.exit(1);
});
