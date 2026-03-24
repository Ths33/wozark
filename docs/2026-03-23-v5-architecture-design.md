# Wbot V5 Architecture Design

**Date**: 2026-03-23
**Status**: Approved
**Scope**: Full system redesign — 3 independent projects replacing V4 monorepo

## Motivation

V4 is a monorepo (React SPA + Fastify backend) where everything runs in a single process. The edge is timing — milliseconds matter for METAR detection → trade execution. V4 bottlenecks:

- Single process: a frontend build or API bug can crash the trading pipeline
- Tightly coupled: changing harvest logic risks breaking rotate
- METAR parsing in JS: adequate but not optimal for the hot path
- No real-time push: dashboard polls every 10-15s
- Limited observability: can't trace a signal end-to-end

V5 separates concerns into 3 independent projects with clear boundaries, independent deploys, and a dedicated East Coast server for proximity to CLOB infrastructure.

## Architecture Overview

```
CapRover (East Coast VPS)

  RUTH (Rust)          WENDY (TypeScript)        MARTY (React+Vite)
  Sensor               Brain                      Dashboard
  3s NOAA poll         Trading decisions          Real-time ops center
  METAR parsing        CLOB execution             Manual intervention
                       Threshold detection        Trace analysis
                       Guards + logs
       │                    │    ▲
       │ HTTP POST          │    │ WebSocket
       │ raw METAR data     │    │ push + REST cmds
       ▼                    ▼    │
  ┌─────────┐         ┌─────────┐
  │  Wendy  │         │  Marty  │
  └─────────┘         └─────────┘
       │
       ▼
  PostgreSQL (prod)
  PostgreSQL (staging)
```

### Git Repos

| Repo | CapRover Apps |
|------|---------------|
| `wbot-ruth/` | wbot-ruth-prod, wbot-ruth-staging |
| `wbot-wendy/` | wbot-wendy-prod, wbot-wendy-staging |
| `wbot-marty/` | wbot-marty-prod, wbot-marty-staging |

---

## Project Ruth (Sensor)

**Stack**: Rust (Axum)
**Responsibility**: Capture METAR and PWS data as fast as possible and deliver raw data to Wendy. Ruth is a pure sensor — zero business logic, zero calculations. Wendy decides what the data means.

### Two Data Streams

| Stream | Source | Frequency | Purpose |
|--------|--------|-----------|---------|
| **METAR** | NOAA TGFTP cycles file | 3s poll | Authoritative temperature confirmation |
| **PWS** | Weather Underground API (api.weather.com) | 60s poll | Real-time anticipation data (market prices 5+ min ahead of METAR) |

### What Ruth does

1. Fetches station list from Wendy on startup (`GET /stations/config`) — includes PWS station IDs per airport
2. **METAR stream**: Polls NOAA cycles file every 3s, parses new METARs, POSTs raw data to Wendy
3. **PWS stream**: Polls 3 PWS per airport every 60s via WU API, POSTs raw readings to Wendy
4. Deduplicates METARs (seen set per hour)
5. Uses HTTP `If-Modified-Since` for NOAA 304 cache hits

### What Ruth does NOT do

- No threshold detection, no running max, no bucket calculation
- No spread/gap/confidence calculations (Wendy does all math)
- No knowledge of prices, positions, CLOB, Polymarket
- No trading decisions or guards
- No database access
- No retry logic (that's Wendy's job)

### Signal Payloads

**METAR signal** (every new observation):
```json
{
  "type": "METAR",
  "station": "KMIA",
  "tempC": 27.8,
  "tempF": 82,
  "dewpointC": 17.2,
  "humidityPct": 52,
  "windDeg": 210,
  "windKt": 8,
  "gustKt": null,
  "visibilityM": 9999,
  "cloudLayers": [{"cover": "FEW", "altFt": 4000}],
  "pressureHpa": 1021,
  "metarRaw": "KMIA 231427Z 21008KT 9999 FEW040 28/17 Q1021",
  "metarTime": "2026-03-23T14:27:00Z",
  "capturedAt": "2026-03-23T14:27:03.412Z",
  "traceId": "ruth-metar-kmia-20260323-142703412"
}
```

**PWS signal** (every 60s cycle, per airport):
```json
{
  "type": "PWS",
  "station": "KMIA",
  "readings": [
    {
      "pwsId": "KFLMIAMI448",
      "tempF": 85.3,
      "humidity": 56,
      "windSpeed": 5.0,
      "windGust": 8.0,
      "windDir": 180,
      "dewpointF": 63.0,
      "pressure": 30.10,
      "obsTime": "2026-03-23T14:19:17Z"
    },
    {
      "pwsId": "KFLMIAMI706",
      "tempF": 84.1,
      "humidity": 58,
      "windSpeed": 3.0,
      "windGust": 5.0,
      "windDir": 190,
      "dewpointF": 64.2,
      "pressure": 30.09,
      "obsTime": "2026-03-23T14:19:10Z"
    },
    {
      "pwsId": "KFLMIAMI578",
      "tempF": 86.4,
      "humidity": 52,
      "windSpeed": 6.0,
      "windGust": 10.0,
      "windDir": 170,
      "dewpointF": 62.0,
      "pressure": 30.11,
      "obsTime": "2026-03-23T14:15:28Z"
    }
  ],
  "capturedAt": "2026-03-23T14:20:01.000Z",
  "traceId": "ruth-pws-kmia-20260323-142001000"
}
```

### PWS Station Map (9 airports × 3 PWS each)

| Airport | PWS 1 | PWS 2 | PWS 3 |
|---------|-------|-------|-------|
| KMIA | KFLMIAMI448 (3.2km) | KFLMIAMI706 (3.3km) | KFLMIAMI578 (3.8km) |
| KATL | KGAATLAN557 (2.7km) | KGAHAPEV1 (3.7km) | KGAATLAN378 (7.0km) |
| KLGA | KNYNEWYO1974 (3.0km) | KNYNEWYO1591 (3.2km) | KNYNEWYO1552 (3.7km) |
| KORD | KILROSEM4 (0km) | KILBENSE15 (3.5km) | KILROSEM2 (4.0km) |
| KDAL | KTXDALLA1343 (1.5km) | KTXDALLA1236 (1.9km) | KTXDALLA843 (2.7km) |
| KSEA | KWASEATT2476 (1.6km) | KWASEATT2470 (1.7km) | KWASEATT2478 (1.9km) |
| EGLC | ILONDON828 (1.6km) | ILONDO873 (2.0km) | ILONDO636 (2.2km) |
| LFPG | IROISS4 (2.5km) | ITREMB16 (5.2km) | IMITRY1 (7.2km) |
| CYYZ | IONTARIO1108 (6.7km) | ITORON111 (7.8km) | ITORON175 (7.8km) |

Source: WU v3/location/near API, filtered by qc=OK, sorted by distance.
These IDs are configured in Wendy (`stations.ts`) and fetched by Ruth on startup.

### WU API Details

```
Endpoint: https://api.weather.com/v2/pws/observations/current
Params: apiKey, stationId, numericPrecision=decimal, format=json, units=e
Auth: API key in query string (e1f10a1e78da46f5b10a1e78da96f525)
Rate limit: Conservative at 27 req/min (9 airports × 3 PWS, every 60s)
```

### Auth

`Authorization: Bearer <RUTH_SECRET>` header on every POST to Wendy. Shared secret in both `.env`.

### Resilience

- If Wendy is unreachable, Ruth logs and continues polling. Stale signals are worthless — no queue, no retry.
- Circuit breaker: after 10 consecutive failures, back off to 30s retries until Wendy recovers.
- If a PWS returns no data or error, skip it for that cycle (other 2 PWS still send).

### Health

`GET /health` for CapRover health checks.

### Performance

- METAR: Poll → parse → POST < 50ms (Rust, CPU is microseconds)
- PWS: 27 HTTP requests batched in parallel → POST results < 500ms total
- Real METAR latency dominated by NOAA network (500ms-2s)

---

## Project Wendy (Brain)

**Stack**: TypeScript (Fastify 5), ESM, strict mode
**Responsibility**: Receive raw METAR from Ruth, maintain running max, detect thresholds, make trading decisions, execute CLOB orders, serve data to Marty.

### Architecture: Modular Monolith

```
wbot-wendy/
├── src/
│   ├── modules/
│   │   ├── signal/        ← entry point from Ruth
│   │   │   ├── signal.route.ts
│   │   │   ├── signal.service.ts
│   │   │   └── signal.types.ts
│   │   ├── buy/
│   │   │   ├── buy.route.ts
│   │   │   ├── buy.service.ts
│   │   │   └── buy.types.ts
│   │   ├── sell/
│   │   │   ├── sell.route.ts
│   │   │   ├── sell.service.ts
│   │   │   └── sell.types.ts
│   │   ├── rotate/
│   │   │   ├── rotate.route.ts
│   │   │   ├── rotate.service.ts
│   │   │   └── rotate.types.ts
│   │   ├── harvest/
│   │   │   ├── harvest.route.ts
│   │   │   ├── harvest.service.ts
│   │   │   └── harvest.types.ts
│   │   ├── positions/
│   │   │   ├── positions.route.ts
│   │   │   ├── positions.service.ts
│   │   │   └── positions.types.ts
│   │   └── monitor/
│   │       ├── monitor.route.ts
│   │       ├── monitor.service.ts
│   │       └── monitor.types.ts
│   ├── shared/
│   │   ├── clob/          ← CLOB client wrapper (SDK)
│   │   │   ├── client.ts
│   │   │   ├── orders.ts
│   │   │   └── verify.ts
│   │   ├── market/        ← Gamma API + in-memory cache
│   │   │   ├── gamma.ts
│   │   │   └── cache.ts
│   │   ├── db/            ← PostgreSQL (Drizzle)
│   │   │   ├── schema.ts
│   │   │   ├── connection.ts
│   │   │   └── queries.ts
│   │   ├── ws/            ← WebSocket broadcaster
│   │   │   └── broadcaster.ts
│   │   ├── stations.ts    ← Station config (single source of truth)
│   │   ├── guards.ts      ← Price, time, daily loss, book liquidity
│   │   ├── logger.ts      ← Pino + DB logging with trace_id
│   │   └── config.ts      ← Settings from DB
│   ├── server.ts          ← Fastify bootstrap + module registration
│   └── types.ts           ← Global types
├── package.json
├── tsconfig.json
├── Dockerfile
└── captain-definition
```

### Station Config — Single Source of Truth

Station definitions (ICAO, timezone, unit, bucket size, polymarket slug) live only in Wendy (`shared/stations.ts`). Ruth fetches the station list from `GET /stations/config` on startup. This eliminates cross-language config drift — bucket calculation, unit conversion, and timezone logic all live in TypeScript only.

### Gamma API Cache

In-memory cache with 2min TTL, refreshed proactively every 30s for enabled stations. No Redis needed. Marty reads market data through Wendy's REST/WS — never hits Gamma directly.

### Module Independence Rules

1. Each module has its own `service.ts` with a clear `execute()` function
2. No module imports from another module — only from `shared/`
3. `rotate` receives buy, sell, harvest services via **dependency injection** at bootstrap (not direct import)
4. ROTATE is BUY-first: BUY executes, only on success SELL + harvest fire in parallel

```typescript
// rotate.service.ts
export class RotateService {
  constructor(
    private buy: BuyService,
    private sell: SellService,
    private harvest: HarvestService,
  ) {}

  async execute(params: RotateParams): Promise<RotateResult> {
    // BUY first — if it fails, position stays in old bucket
    const buyResult = await this.buy.execute({ ... })
    if (!buyResult.success) {
      return { success: false, reason: 'buy_failed', buyResult }
    }

    // BUY succeeded → SELL old + harvest dead in parallel
    const [sellResult, harvestResult] = await Promise.allSettled([
      this.sell.execute({ ... }),
      this.harvest.execute({ ... }),
    ])

    return { success: true, buyResult, sellResult, harvestResult }
  }
}
```

### Signal Flow (Ruth → Wendy)

Two signal types arrive from Ruth:

**METAR signal** (authoritative, every new observation):
```
POST /signal { type: "METAR", ... }
  │
  signal.service.ts
  │
  ├─ Validate payload (Zod) + verify RUTH_SECRET
  ├─ Save METAR to DB (fire-and-forget, never blocks)
  ├─ Broadcast to Marty via WS: "new METAR"
  │
  ├─ Update running max for station (in-memory)
  ├─ Calculate bucket from temperature
  │
  ├─ Day changed (local tz)?
  │   └─ Reset running max + confirmed buckets + PWS history, return
  │
  ├─ No bucket change?
  │   └─ Log NEW_METAR, return
  │
  ├─ Bucket crossed (threshold)?
  │   ├─ Guards check (guards.ts):
  │   │   ├─ Local time >= 7am?
  │   │   ├─ Gamma price 10%-75%?
  │   │   ├─ Book has liquidity?
  │   │   ├─ Daily loss limit ok?
  │   │   └─ Trade lock free?
  │   │
  │   ├─ Has position in previous bucket?
  │   │   ├─ YES → rotate.service.execute(traceId)
  │   │   │         ├─ buy.execute(new bucket)           ← first
  │   │   │         ├─ sell.execute(old bucket)   ─┐
  │   │   │         └─ harvest.execute(dead)      ─┘ parallel after buy
  │   │   └─ NO → buy.execute(new bucket)
  │   │           + harvest.execute(dead)
  │   │
  │   └─ Broadcast to Marty via WS: result
  │
  └─ Retry window active?
      └─ Similar with own guards, confirmedBuckets tracking
```

**PWS signal** (anticipation, every 60s):
```
POST /signal { type: "PWS", station, readings: [...] }
  │
  signal.service.ts → anticipation.service.ts
  │
  ├─ Validate payload (Zod) + verify RUTH_SECRET
  ├─ Store readings in PWS history ring buffer (last 15min per station)
  ├─ Broadcast to Marty via WS: "pws_update" (dashboard shows real-time PWS)
  │
  ├─ Calculate anticipation:
  │   ├─ T_pws = median(readings[].temp)
  │   ├─ T_metar = last confirmed METAR temp for station
  │   ├─ gap = T_pws - T_metar
  │   ├─ conf = count(readings where temp >= T_metar) / total readings
  │   ├─ ramp = linear regression of PWS medians over last 10min (°/hour)
  │   ├─ α = station-specific factor (0.5-0.8, based on PWS distance)
  │   ├─ β = 0.3 (trend weight)
  │   ├─ T_estimated = T_metar + (gap * conf * α) + (ramp * β)
  │   └─ predicted_bucket = getBucket(T_estimated)
  │
  ├─ predicted_bucket == current METAR bucket?
  │   └─ No signal, return
  │
  ├─ Confidence evaluation:
  │   ├─ STRONG: gap > 2°F (1°C) AND conf > 0.7 → execute anticipation trade
  │   ├─ MODERATE: gap > 1°F AND conf > 0.6 → log alert, no trade yet
  │   └─ WEAK: gap < 1°F OR conf < 0.5 → ignore
  │
  ├─ STRONG signal → same guards as METAR threshold + buy.execute()
  │   (BUY only, never ROTATE on anticipation — METAR confirms ROTATE)
  │
  └─ Broadcast to Marty via WS: anticipation status
```

### Anticipation Rules

- PWS anticipation triggers **BUY only** (never ROTATE or SELL — METAR is required for position changes)
- If anticipation BUY succeeds and METAR later confirms → METAR may trigger ROTATE to next bucket
- If anticipation BUY succeeds but METAR doesn't confirm → position held, no stop-loss (same as V4)
- α (station factor) configured per station in `stations.ts`, tunable via Settings page
- PWS history ring buffer: stores last 15 minutes of median readings per station for ramp calculation

### Monitor Module

Runs on a timer (every 3 minutes):
- **Price snapshots**: Fetch current Gamma prices for all positioned markets
- **Duplicate cleanup**: If 2+ positions on same station, sell the smaller one
- **SELL retry**: Retry failed sells with backoff (3 consecutive failures → give up for that position)
- **Position cache invalidation**: Refresh CLOB positions for dashboard accuracy

### DB Writes Are Never Blocking

All database operations are fire-and-forget. The critical path is: received → guards → CLOB order. DB is a side-effect that runs in parallel. If PostgreSQL is slow or down, trades execute regardless.

```typescript
// Always:
db.saveMetar(data).catch(log.error)    // fire and forget
db.logActivity(trace).catch(log.error) // fire and forget

// Never:
await db.saveMetar(data)   // blocks the flow
```

### Endpoints

| Endpoint | Source | Purpose |
|----------|--------|---------|
| `POST /signal` | Ruth | Receive raw METAR (auth: RUTH_SECRET) |
| `GET /stations/config` | Ruth | Station list for polling |
| `GET /health` | CapRover | Health check |
| `POST /buy` | Marty | Manual buy (auth: JWT) |
| `POST /sell` | Marty | Manual close position (auth: JWT) |
| `GET /positions` | Marty | Current positions + P&L (auth: JWT) |
| `GET /balance` | Marty | USDC balance + daily loss (auth: JWT) |
| `GET /logs` | Marty | Filterable logs with trace_id (auth: JWT) |
| `GET /stations` | Marty | Station data + market prices (auth: JWT) |
| `GET /settings` | Marty | Current bot config (auth: JWT) |
| `POST /settings` | Marty | Update bot config (auth: JWT) |
| `WS /ws` | Marty | Real-time push events (auth: JWT on handshake) |

---

## Project Marty (Dashboard)

**Stack**: React 19 + Vite + Tailwind v4 + Flowbite React (SPA, no SSR needed)
**Font**: Manrope, dark mode class-based
**Responsibility**: Real-time operations center — see everything, intervene in bot decisions.

### Structure

```
wbot-marty/
├── src/
│   ├── pages/
│   │   ├── Login.tsx
│   │   ├── Dashboard.tsx      ← station cards, real-time
│   │   ├── Positions.tsx      ← open, losses, redeem
│   │   ├── Logs.tsx           ← extensive, filterable, trace_id
│   │   └── Settings.tsx       ← bot config
│   ├── components/
│   │   ├── StationCard.tsx
│   │   ├── PositionList.tsx
│   │   ├── LogViewer.tsx
│   │   └── TraceTimeline.tsx  ← full trace visualization
│   ├── lib/
│   │   ├── ws.ts              ← WebSocket client (auto-reconnect)
│   │   ├── api.ts             ← REST client for Wendy
│   │   └── auth.ts            ← JWT storage + refresh
│   └── hooks/
│       ├── useWebSocket.ts
│       ├── usePositions.ts
│       └── useStations.ts
├── package.json
├── Dockerfile
└── captain-definition
```

### Communication with Wendy

**Push (Wendy → Marty via WebSocket):**

| Event | Trigger |
|-------|---------|
| `new_metar` | Ruth sent new observation |
| `trade_executed` | Buy/sell/rotate completed |
| `trade_skipped` | Signal received but guards blocked |
| `error` | Something failed |
| `position_update` | P&L refresh |

**Commands (Marty → Wendy via REST):**
- `POST /buy` — manual buy
- `POST /sell` — manual close
- `POST /settings` — config updates

### WebSocket Auth

JWT validated on handshake. Wendy checks token expiry on connect and periodically re-validates. If token expires, Wendy closes the WS connection and Marty auto-reconnects with a refreshed token.

### Logs Page

- Filter by station, type, source, date range
- Search by trace_id — click a trade, see the full chain
- TraceTimeline component — chronological visualization:
  ```
  14:27:03.412  RUTH   METAR captured EGLC 15.3C
  14:27:03.414  WENDY  Signal received, threshold crossed 14→15
  14:27:03.415  WENDY  Guards OK: price 21c, book 12 bids
  14:27:03.890  WENDY  BUY YES bucket 15 — FOK sent
  14:27:04.312  WENDY  BUY confirmed, 4.76 shares @ 0.21
  14:27:04.315  WENDY  SELL YES bucket 14 — FOK sent
  14:27:04.780  WENDY  SELL confirmed, 3.2 shares @ 0.03
  ```
- CSV export for offline analysis

---

## Database

### Infrastructure

```
PostgreSQL server (CapRover)
├── wbot_prod      ← production
└── wbot_staging   ← staging (DRY_MODE, simulation)
```

Same schema in both. Each app connects via `DATABASE_URL`.

### Schema

```sql
-- METAR observations (Ruth sends, Wendy saves)
metar_observations (
  id            serial PRIMARY KEY,
  station       varchar(4) NOT NULL,
  temp_c        real NOT NULL,
  dewpoint_c    real,
  humidity_pct  smallint,
  wind_deg      smallint,
  wind_kt       smallint,
  gust_kt       smallint,
  visibility_m  int,
  cloud_layers  jsonb,
  pressure_hpa  real,
  metar_raw     text NOT NULL,
  valid_utc     timestamptz NOT NULL,
  captured_at   timestamptz NOT NULL,
  trace_id      varchar(64) NOT NULL,
  created_at    timestamptz DEFAULT now()
)

-- Executed trades
trades (
  id            serial PRIMARY KEY,
  trace_id      varchar(64) NOT NULL,
  station       varchar(4) NOT NULL,
  action        varchar(10) NOT NULL,  -- BUY, SELL, HARVEST
  side          varchar(3) NOT NULL,   -- YES, NO
  bucket        varchar(20) NOT NULL,
  token_id      varchar(128),
  amount        numeric(10,2),         -- dollars (BUY) or shares (SELL)
  shares        numeric(10,2),
  price         numeric(8,6),
  order_id      varchar(128),
  fill_status   varchar(10),           -- FILLED, PHANTOM, FAILED
  signal_type   varchar(10) NOT NULL,  -- TGFTP, MANUAL
  dry_run       boolean DEFAULT false,
  created_at    timestamptz DEFAULT now()
)

-- Unified logs (trace_id connects everything)
logs (
  id            serial PRIMARY KEY,
  trace_id      varchar(64),
  service       varchar(10) NOT NULL,  -- ruth, wendy, marty
  station       varchar(4),
  level         varchar(10) NOT NULL,  -- debug, info, warn, error, success
  category      varchar(20),           -- signal, guard, trade, position, config
  message       text NOT NULL,
  metadata      jsonb,                 -- extra data (price, shares, skip reason)
  created_at    timestamptz DEFAULT now()
)

-- Bot config (key-value)
app_config (
  key           varchar(50) PRIMARY KEY,
  value         text NOT NULL,
  updated_at    timestamptz DEFAULT now()
)

-- Auth (JWT blacklist for logout)
auth_sessions (
  id            serial PRIMARY KEY,
  token_hash    varchar(128) NOT NULL,
  expires_at    timestamptz NOT NULL,
  revoked       boolean DEFAULT false,
  created_at    timestamptz DEFAULT now()
)
```

### Indexes

```sql
CREATE INDEX idx_metar_station_date ON metar_observations(station, valid_utc);
CREATE INDEX idx_trades_station ON trades(station, created_at);
CREATE INDEX idx_trades_trace ON trades(trace_id);
CREATE INDEX idx_logs_trace ON logs(trace_id);
CREATE INDEX idx_logs_service_date ON logs(service, created_at);
CREATE INDEX idx_logs_station_date ON logs(station, created_at);
```

### Log Retention

The `logs` table grows fast (~345k rows/day at peak). Partition by month. Retain 90 days online, archive older data to CSV. `metar_observations` and `trades` are never truncated — they feed analytics.

### Access Matrix

| Table | Ruth | Wendy | Marty |
|-------|------|-------|-------|
| metar_observations | — | write | read (via Wendy API) |
| trades | — | write + read | read (via Wendy API) |
| logs | — | write + read | read (via Wendy API) |
| app_config | — | read + write | read + write (via Wendy API) |
| auth_sessions | — | read + write | — |

Ruth has zero DB access. Marty reads everything through Wendy's REST API — no direct DB connection.

---

## Trace ID and Observability

### Format

```
{service}-{station}-{YYYYMMDD}-{HHmmssSSS}
```

Examples:
- `ruth-eglc-20260323-142703412` — Ruth captured METAR
- `marty-manual-20260323-160045123` — Manual action from dashboard

### Lifecycle

Ruth generates the trace_id. Wendy propagates it through every log, trade, and decision made from that signal. Marty displays it and allows filtering.

Even skipped signals produce a trace — for studying "why didn't it enter?"

### Extractable Metrics

- **Ruth→Wendy latency**: `capturedAt` vs first Wendy log
- **Total latency**: `capturedAt` vs trade confirmed
- **Skip rate**: signals that became trades vs skips, per station
- **Skip reasons**: aggregation by guard type (price, book, time, loss)
- **Station performance**: ROI per station over time
- **Capture delay**: `capturedAt` vs `metarTime` (NOAA publish delay)

---

## Deploy and Release Flow

### Git Workflow

```
wbot-ruth/     main ← staging ← feat/*
wbot-wendy/    main ← staging ← feat/*
wbot-marty/    main ← staging ← feat/*
```

### CapRover Apps

```
CapRover
├── wbot-ruth-prod        ← deploy: push main
├── wbot-ruth-staging     ← deploy: push staging
├── wbot-wendy-prod       ← deploy: push main
├── wbot-wendy-staging    ← deploy: push staging
├── wbot-marty-prod       ← deploy: push main
├── wbot-marty-staging    ← deploy: push staging
├── wbot-db-prod          ← PostgreSQL (persistent volume)
└── wbot-db-staging       ← PostgreSQL (persistent volume)
```

### Release Process

```
1. FEAT:    feat/improve-harvest → develop + test locally
2. STAGING: merge feat → staging → auto-deploy staging app
             staging uses DRY_MODE=true, staging DB
             validate: logs, decisions, latency, no crash
3. PROD:    merge staging → main → auto-deploy prod app
             only the changed project deploys
```

### Deploy Independence

Updating Wendy's harvest logic:
1. `wbot-wendy: feat/harvest-limit-fallback`
2. Test locally
3. Push staging → Wendy staging deploys
4. Ruth staging keeps sending signals → Wendy staging processes with DRY_MODE
5. All OK → merge main → Wendy prod deploys
6. Ruth prod and Marty prod: zero downtime, no redeploy

### Environment Variables

```env
# Ruth (.env)
NOAA_POLL_INTERVAL_MS=3000
WENDY_URL=http://srv-captain--wbot-wendy-prod:3000
RUTH_SECRET=<shared-secret>

# Wendy (.env)
DATABASE_URL=postgresql://...
RUTH_SECRET=<shared-secret>
POLY_API_KEY=...
POLY_API_SECRET=...
POLY_PASSPHRASE=...
POLY_ADDRESS=...
JWT_SECRET=...
DRY_MODE=false

# Marty (.env)
WENDY_URL=http://srv-captain--wbot-wendy-prod:3000
WENDY_WS_URL=ws://srv-captain--wbot-wendy-prod:3000/ws
```

CLOB credentials only in Wendy. Ruth and Marty have no access.

---

## Auth

**Ruth → Wendy**: Shared secret (`RUTH_SECRET`) in Authorization header.
**Marty → Wendy**: JWT tokens.
- Marty login → Wendy validates password → returns JWT
- JWT used in REST headers and WebSocket handshake
- WebSocket: JWT validated on connect, re-validated periodically, connection closed on expiry
- `auth_sessions` table for logout (token blacklist)

---

## Stations (9)

| Region | Stations | Unit | Bucket Size |
|--------|----------|------|-------------|
| US | Seattle (KSEA), Dallas (KDAL), Chicago (KORD), New York (KLGA), Miami (KMIA), Atlanta (KATL) | F | 2F |
| EU | London (EGLC), Paris (LFPG) | C | 1C |
| Americas | Toronto (CYYZ) | C | 1C |

**Removed**: Seoul (RKSI), São Paulo (SBGR), Tokyo (RJTT) — poor PWS coverage, bad trading results. Shanghai (ZSPD) — TGFTP delays. Milan (LIML) — wrong ICAO.

**Single source of truth**: Station config lives in Wendy (`shared/stations.ts`) — includes ICAO, timezone, unit, polymarket slug, AND PWS station IDs per airport. Ruth fetches station list from `GET /stations/config` on startup. Bucket calculation, unit conversion, timezone logic, anticipation formula — all in TypeScript only.

Runtime station toggles via Settings page (stored in `app_config`). Ruth re-fetches station list periodically or on Wendy restart.

---

## Trading Rules (carried from V4)

All V4 trading guards carry over to V5, implemented in `wendy/src/shared/guards.ts`:

- Before 7am local time → skip
- Gamma < 10% → skip (no liquidity)
- Gamma >= 75% → skip (market converged)
- Gamma >= 100% → resolved, stop retry for bucket
- Dead bucket (no bids in CLOB book) → skip
- Border zone (0.45-0.55 decimal) → wait for next METAR
- Daily loss limit before every non-rotate BUY
- Trade locks prevent double-purchase on same station:bucket
- NO Harvest: only when NO price > 0 and < 75c
- FOK verification via getOrder() + size_matched
- SELL retry: check book, 0 shares = stop, 400 = retry up to 3x
- No stop-loss — hold until resolution
- ROTATE: BUY first, if BUY fails → no SELL (position stays in old bucket)

### CLOB Rules (carried from V4)

- `createAndPostMarketOrder`: FOK, BUY=dollars, SELL=shares
- `createOrder` + `postOrder(GTC)`: limit orders (NO Harvest fallback)
- `negRisk: true` always
- `tickSize: '0.01'` always
- Shares precision: `Math.floor(shares * 100) / 100`
- Verify fills via `getOrder(orderId).size_matched`
- Order statuses: matched, delayed (retry getOrder), null (not visible yet)
- NEVER improvise CLOB code — study SDK source before any change

---

## Dropped from V5 (intentional)

| Feature | Reason |
|---------|--------|
| **AI Predictor (GPT-4o)** | Replaced by PWS anticipation — data-driven, not model-driven |
| **Synoptic Collector** | Replaced by PWS — Weather Underground PWS provides better real-time coverage |
| **Edge Alert** | Never generated trades, only logs. Low value |
| **Redeem** | Manual via Polymarket UI. Not worth automating now |
| **Seoul (RKSI)** | Poor PWS coverage (41km+), bad trading results |
| **São Paulo (SBGR)** | Poor PWS coverage (22km+), bad trading results |
| **Tokyo (RJTT)** | Poor PWS coverage (8.6km), bad trading results |

These can be re-added as new modules in Wendy without touching existing code.

---

## Summary of Decisions

| Decision | Choice |
|----------|--------|
| Ruth stack | Rust (Axum) |
| Ruth responsibility | Pure sensor — capture METAR + PWS, POST raw data to Wendy, zero business logic |
| Ruth PWS stream | 3 PWS per airport, 60s poll via WU API, raw readings to Wendy |
| Anticipation model | Wendy calculates gap/conf/ramp from PWS, BUY-only on STRONG signals |
| Wendy stack | TypeScript (Fastify 5) |
| Wendy responsibility | All business logic — running max, thresholds, guards, CLOB, positions |
| Wendy architecture | Modular monolith (modules/ + shared/) |
| Marty stack | React 19 + Vite + Tailwind v4 + Flowbite |
| Ruth → Wendy | HTTP POST with shared secret auth |
| Wendy → Marty | WebSocket push + REST commands with JWT auth |
| Infrastructure | CapRover, same East Coast VPS, independent apps |
| Database | PostgreSQL prod + staging (separate databases) |
| Station config | Single source in Wendy, Ruth fetches on startup |
| Cache | In-memory Gamma cache in Wendy (no Redis) |
| Auth | Shared secret (Ruth→Wendy) + JWT (Marty→Wendy) |
| Observability | trace_id end-to-end, unified logs table, partitioned by month |
| Deploy | 3 git repos, feat → staging → main per project |
| ROTATE safety | BUY first, then SELL+harvest parallel only on BUY success |
