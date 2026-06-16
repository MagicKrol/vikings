import { useEffect, useMemo, useState } from "react";

const presets = [
	{ label: "7 days", days: 7, granularity: "day" },
	{ label: "30 days", days: 30, granularity: "day" },
	{ label: "90 days", days: 90, granularity: "week" },
	{ label: "12 months", days: 365, granularity: "month" }
];

const statusTone = {
	won: "good",
	lost: "warn",
	quit: "bad",
	active: "info",
	started: "info"
};

function secondsAgo(days) {
	return Math.floor(Date.now() / 1000) - days * 24 * 60 * 60;
}

function formatDuration(seconds) {
	const value = Number(seconds || 0);
	if (value < 60) {
		return `${Math.round(value)}s`;
	}
	if (value < 3600) {
		return `${Math.round(value / 60)}m`;
	}
	return `${(value / 3600).toFixed(1)}h`;
}

function formatDate(timestamp) {
	if (!timestamp) {
		return "";
	}
	return new Intl.DateTimeFormat("en", {
		month: "short",
		day: "numeric",
		hour: "2-digit",
		minute: "2-digit"
	}).format(new Date(Number(timestamp) * 1000));
}

function percent(value) {
	return `${Number(value || 0).toFixed(1)}%`;
}

function number(value) {
	return new Intl.NumberFormat("en").format(Number(value || 0));
}

function labelOrUnknown(value) {
	return value && String(value).trim() !== "" ? value : "unknown";
}

async function fetchJson(url) {
	let response;
	try {
		response = await fetch(url);
	} catch (_error) {
		throw new Error("Analytics API is not reachable. Start the dashboard with npm run dev from analytics-dashboard.");
	}
	const text = await response.text();
	let payload = null;
	if (text.trim() !== "") {
		try {
			payload = JSON.parse(text);
		} catch (_error) {
			throw new Error("Analytics API returned a non-JSON response. Check that the Node API is running on port 3005.");
		}
	}
	if (!response.ok) {
		throw new Error(payload?.message || payload?.error || `Analytics API request failed with HTTP ${response.status}.`);
	}
	return payload;
}

function MetricCard({ label, value, detail, tone = "neutral" }) {
	return (
		<section className={`metric-card ${tone}`}>
			<div className="metric-label">{label}</div>
			<div className="metric-value">{value}</div>
			<div className="metric-detail">{detail}</div>
		</section>
	);
}

function SelectFilter({ label, value, options, onChange }) {
	return (
		<label className="filter">
			<span>{label}</span>
			<select value={value} onChange={(event) => onChange(event.target.value)}>
				<option value="">All</option>
				{options.map((option) => (
					<option value={option.value} key={option.value}>
						{option.value}
					</option>
				))}
			</select>
		</label>
	);
}

function BarChart({ rows, labelKey, valueKey, valueLabel }) {
	const maxValue = Math.max(1, ...rows.map((row) => Number(row[valueKey] || 0)));
	return (
		<div className="bar-chart">
			{rows.map((row) => {
				const value = Number(row[valueKey] || 0);
				const width = `${Math.max(2, (value / maxValue) * 100)}%`;
				return (
					<div className="bar-row" key={row[labelKey]}>
						<div className="bar-label">{labelOrUnknown(row[labelKey])}</div>
						<div className="bar-track">
							<div className="bar-fill" style={{ width }} />
						</div>
						<div className="bar-value">{valueLabel ? valueLabel(row) : number(value)}</div>
					</div>
				);
			})}
		</div>
	);
}

function LineChart({ rows }) {
	const width = 780;
	const height = 250;
	const padding = {
		top: 22,
		right: 24,
		bottom: 36,
		left: 56
	};
	const maxRuns = Math.max(1, ...rows.map((row) => Number(row.total_runs || 0)));
	const yTicks = [maxRuns, Math.round(maxRuns / 2), 0].filter((value, index, values) => values.indexOf(value) === index);
	const points = rows.map((row, index) => {
		const x = rows.length === 1 ? width / 2 : padding.left + (index / (rows.length - 1)) * (width - padding.left - padding.right);
		const y = height - padding.bottom - (Number(row.total_runs || 0) / maxRuns) * (height - padding.top - padding.bottom);
		return { x, y, row };
	});
	const path = points.map((point, index) => `${index === 0 ? "M" : "L"} ${point.x} ${point.y}`).join(" ");
	return (
		<div className="line-chart">
			<svg viewBox={`0 0 ${width} ${height}`} role="img" aria-label="Runs over time">
				{yTicks.map((tick) => {
					const y = height - padding.bottom - (tick / maxRuns) * (height - padding.top - padding.bottom);
					return (
						<g key={tick}>
							<path className="grid-line" d={`M ${padding.left} ${y} L ${width - padding.right} ${y}`} />
							<text className="axis-text" x={padding.left - 10} y={y + 4} textAnchor="end">{number(tick)}</text>
						</g>
					);
				})}
				<path className="line-path" d={path} />
				{points.map((point) => (
					<g key={point.row.bucket}>
						<title>{`${point.row.bucket}: ${number(point.row.total_runs)} runs`}</title>
						<circle className="line-dot" cx={point.x} cy={point.y} r="4" />
						<text className="chart-value-label" x={point.x} y={Math.max(14, point.y - 9)} textAnchor="middle">{number(point.row.total_runs)}</text>
					</g>
				))}
			</svg>
			<div className="line-labels">
				{rows.slice(0, 8).map((row) => (
					<span key={row.bucket}>{row.bucket}</span>
				))}
			</div>
		</div>
	);
}

function ContentTable({ rows }) {
	return (
		<div className="table-wrap">
			<table>
				<thead>
					<tr>
						<th>Content</th>
						<th>Mode</th>
						<th>Runs</th>
						<th>Finished / runs</th>
						<th>Won / finished</th>
						<th>Lost / finished</th>
						<th>Quit / runs</th>
						<th>Avg time</th>
						<th>Avg turns</th>
						<th>Avg win turns</th>
						<th>Min win turns</th>
					</tr>
				</thead>
				<tbody>
					{rows.map((row) => (
						<tr key={`${row.content_type}:${row.content_id}:${row.game_mode}`}>
							<td>
								<strong>{labelOrUnknown(row.content_id)}</strong>
								<span>{labelOrUnknown(row.content_type)}</span>
							</td>
							<td>{labelOrUnknown(row.game_mode)}</td>
							<td>{number(row.total_runs)}</td>
							<td>{percent((Number(row.completed_runs || 0) / Math.max(1, Number(row.total_runs || 0))) * 100)}</td>
							<td>{percent((Number(row.won_runs || 0) / Math.max(1, Number(row.completed_runs || 0))) * 100)}</td>
							<td>{percent((Number(row.lost_runs || 0) / Math.max(1, Number(row.completed_runs || 0))) * 100)}</td>
							<td>{percent((Number(row.quit_runs || 0) / Math.max(1, Number(row.total_runs || 0))) * 100)}</td>
							<td>{formatDuration(row.avg_seconds)}</td>
							<td>{Number(row.avg_turns || 0).toFixed(1)}</td>
							<td>{row.avg_win_turns ? Number(row.avg_win_turns).toFixed(1) : "-"}</td>
							<td>{row.min_win_turns ? number(row.min_win_turns) : "-"}</td>
						</tr>
					))}
				</tbody>
			</table>
		</div>
	);
}

function RecentRuns({ rows }) {
	return (
		<div className="recent-list">
			{rows.slice(0, 18).map((row) => (
				<div className="run-row" key={row.run_id}>
					<div>
						<strong>{labelOrUnknown(row.content_id)}</strong>
						<span>{formatDate(row.started_ts)} - {labelOrUnknown(row.difficulty)} - {formatDuration(row.elapsed_seconds)} - turn {number(row.turn_count)}</span>
					</div>
					<span className={`status-pill ${statusTone[row.status] || "neutral"}`}>{labelOrUnknown(row.status)}</span>
				</div>
			))}
		</div>
	);
}

function EmptyState({ message }) {
	return (
		<div className="empty-state">
			<div>No analytics loaded</div>
			<p>{message}</p>
		</div>
	);
}

export default function App() {
	const [preset, setPreset] = useState(presets[1]);
	const [filters, setFilters] = useState({
		contentType: "",
		difficulty: "",
		gameMode: "",
		status: "",
		build: "",
		platform: "",
		includeInternal: false
	});
	const [options, setOptions] = useState({
		contentTypes: [],
		difficulties: [],
		gameModes: [],
		statuses: [],
		builds: [],
		platforms: []
	});
	const [data, setData] = useState(null);
	const [error, setError] = useState("");
	const [loading, setLoading] = useState(false);

	const query = useMemo(() => {
		const params = new URLSearchParams({
			from: String(secondsAgo(preset.days)),
			to: String(Math.floor(Date.now() / 1000) + 1),
			granularity: preset.granularity,
			includeInternal: String(filters.includeInternal)
		});
		for (const key of ["contentType", "difficulty", "gameMode", "status", "build", "platform"]) {
			if (filters[key]) {
				params.set(key, filters[key]);
			}
		}
		return params.toString();
	}, [filters, preset]);

	useEffect(() => {
		fetchJson("/api/analytics/options")
			.then((payload) => {
				if (!payload.error) {
					setOptions(payload);
				}
			})
			.catch(() => {});
	}, []);

	useEffect(() => {
		setLoading(true);
		setError("");
		fetchJson(`/api/analytics?${query}`)
			.then((payload) => {
				setData(payload);
			})
			.catch((caught) => {
				setData(null);
				setError(caught instanceof Error ? caught.message : "Unable to load analytics");
			})
			.finally(() => setLoading(false));
	}, [query]);

	const summary = data?.summary;

	return (
		<main className="dashboard-shell">
			<header className="topbar">
				<div>
					<p className="eyebrow">Horn of the Warlord</p>
					<h1>Analytics Dashboard</h1>
				</div>
				<div className="preset-group" aria-label="Time period">
					{presets.map((item) => (
						<button
							type="button"
							className={item.label === preset.label ? "active" : ""}
							onClick={() => setPreset(item)}
							key={item.label}
						>
							{item.label}
						</button>
					))}
				</div>
			</header>

			<section className="filters-panel">
				<SelectFilter label="Content type" value={filters.contentType} options={options.contentTypes} onChange={(value) => setFilters({ ...filters, contentType: value })} />
				<SelectFilter label="Difficulty" value={filters.difficulty} options={options.difficulties} onChange={(value) => setFilters({ ...filters, difficulty: value })} />
				<SelectFilter label="Game mode" value={filters.gameMode} options={options.gameModes} onChange={(value) => setFilters({ ...filters, gameMode: value })} />
				<SelectFilter label="Status" value={filters.status} options={options.statuses} onChange={(value) => setFilters({ ...filters, status: value })} />
				<SelectFilter label="Build" value={filters.build} options={options.builds} onChange={(value) => setFilters({ ...filters, build: value })} />
				<SelectFilter label="Platform" value={filters.platform} options={options.platforms} onChange={(value) => setFilters({ ...filters, platform: value })} />
				<label className="toggle-filter">
					<input
						type="checkbox"
						checked={filters.includeInternal}
						onChange={(event) => setFilters({ ...filters, includeInternal: event.target.checked })}
					/>
					<span>Include internal/my runs</span>
				</label>
			</section>

			{error && <EmptyState message={error} />}
			{loading && !data && <EmptyState message="Loading database metrics..." />}

			{summary && (
				<>
					<section className="metrics-grid">
						<MetricCard label="Runs" value={number(summary.totalRuns)} detail={`${number(summary.uniquePlayers)} unique players`} />
						<MetricCard label="Finish rate" value={percent(summary.finishRate)} detail={`${number(summary.completedRuns)} won/lost completions`} tone="good" />
						<MetricCard label="Quit rate" value={percent(summary.quitRate)} detail={`${number(summary.quitRuns)} quit outcomes`} tone="bad" />
						<MetricCard label="Average run" value={formatDuration(summary.avgSeconds)} detail={`${Number(summary.avgTurns || 0).toFixed(1)} turns on average`} />
						<MetricCard label="Win rate" value={percent(summary.winRate)} detail={`${number(summary.wonRuns)} wins from completed games`} tone="warn" />
						<MetricCard label="Open runs" value={number(summary.openRuns)} detail="started or active without terminal outcome" />
					</section>
					{data.excludedUserCount > 0 && !filters.includeInternal && (
						<div className="data-note">
							Excluding {number(data.excludedUserCount)} configured owner/test user ID plus rows marked internal.
						</div>
					)}

					<section className="main-grid">
						<div className="panel wide">
							<div className="panel-header">
								<h2>Runs over time</h2>
								<span>{preset.granularity}</span>
							</div>
							<LineChart rows={data.timeSeries} />
						</div>

						<div className="panel">
							<div className="panel-header">
								<h2>Difficulty mix</h2>
								<span>runs</span>
							</div>
							<BarChart rows={data.difficultyRows} labelKey="difficulty" valueKey="total_runs" />
						</div>

						<div className="panel">
							<div className="panel-header">
								<h2>Run length</h2>
								<span>duration buckets</span>
							</div>
							<BarChart rows={data.durationRows} labelKey="bucket" valueKey="total_runs" />
						</div>

						<div className="panel">
							<div className="panel-header">
								<h2>Outcome split</h2>
								<span>status</span>
							</div>
							<BarChart rows={data.statusRows} labelKey="status" valueKey="total_runs" />
						</div>

						<div className="panel">
							<div className="panel-header">
								<h2>Platforms</h2>
								<span>runs</span>
							</div>
							<BarChart rows={data.platformRows} labelKey="platform" valueKey="total_runs" />
						</div>

						<div className="panel wide">
							<div className="panel-header">
								<h2>Content performance</h2>
								<span>top 40</span>
							</div>
							<ContentTable rows={data.contentRows} />
						</div>

						<div className="panel">
							<div className="panel-header">
								<h2>Event volume</h2>
								<span>raw events</span>
							</div>
							<BarChart rows={data.eventRows} labelKey="event_name" valueKey="total_events" />
						</div>

						<div className="panel">
							<div className="panel-header">
								<h2>Recent runs</h2>
								<span>latest</span>
							</div>
							<RecentRuns rows={data.recentRuns} />
						</div>
					</section>
				</>
			)}
		</main>
	);
}
