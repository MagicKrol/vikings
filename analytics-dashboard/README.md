# Vikings Analytics Dashboard

React/Node dashboard for the telemetry stored by `analytics.gd`, `heartbeat.php`, and `analytics_schema.sql`.

## What it answers

- Which game/content types are played most often.
- Average game duration and turn count.
- Completed game rate: `won + lost` divided by all runs.
- Quit rate and open/abandoned run count.
- Win rate for completed games.
- Difficulty, platform, build, and status distribution.
- Trends across 7 days, 30 days, 90 days, or 12 months.
- Recent individual runs for spot checks.

## Run locally

```bash
cd analytics-dashboard
cp .env.example .env
npm install
npm run server
```

In another terminal:

```bash
cd analytics-dashboard
npm run dev
```

Open `http://127.0.0.1:5173`.

For production-style serving:

```bash
cd analytics-dashboard
npm run build
npm start
```

Then open `http://127.0.0.1:3005`.

## Environment

Set these variables in `.env` or in the shell before starting `npm run server`:

- `ANALYTICS_DB_HOST`
- `ANALYTICS_DB_PORT`
- `ANALYTICS_DB_NAME`
- `ANALYTICS_DB_USER`
- `ANALYTICS_DB_PASSWORD`
- `ANALYTICS_SERVER_PORT`
- `ANALYTICS_EXCLUDED_USER_IDS` comma-separated analytics `user_id` values to exclude from normal dashboard data

Internal/editor runs and `ANALYTICS_EXCLUDED_USER_IDS` are excluded by default, including the raw event volume panel. Use the dashboard checkbox to include rows marked by `analytics_runs.is_internal = 1`, event payloads where `is_internal` is `true`, and configured excluded owner/test user IDs.
