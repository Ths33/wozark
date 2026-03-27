# CLAUDE.md — Wozark (Wbot V5 Master)

## Language

- Always communicate in **Portuguese (BR)** — all conversation, explanations, questions, status updates
- Code (variables, functions, comments, commits) stays in **English**

## Project

Wozark is a weather temperature auto-trading system for Polymarket. It consists of 4 deployed projects that work together to capture weather data, predict daily highs, make trading decisions, and provide a real-time operations dashboard.

**CapRover panel:** https://captain.wozark.com/
**VPS IP:** 168.231.70.56 (East Coast)

## Architecture

```
Ruth (Rust/Axum)       Wendy (TypeScript/Fastify)      Marty (React/Vite)       Jonah (Python/FastAPI)
Sensor                 Brain                            Dashboard                Analyst (V5 Ensemble)
├─ METAR 3s poll       ├─ Threshold detection           ├─ Station cards          ├─ 5-source ensemble:
├─ PWS 60s poll        ├─ Trading guards                ├─ Positions + P&L        │  LightGBM, Chronos,
└─ POST → Wendy+Jonah  ├─ CLOB execution (buy/sell)     ├─ Logs + trace timeline  │  Open-Meteo, RAG, GPT-5
                       ├─ PWS anticipation (strict)     ├─ Settings + toggles     ├─ Range detection + timing
                       ├─ WebSocket push → Marty        └─ Manual buy/sell        ├─ Qdrant RAG (auto-learning)
                       └─ PostgreSQL logging                                      └─ Advisory → Wendy
```

## Projects

| Project | Directory | Stack | URL | Port | Status |
|---------|-----------|-------|-----|------|--------|
| **Ruth** | `wbot-ruth/` | Rust, Axum, Tokio | internal only | 8080 | Deployed |
| **Wendy** | `wbot-wendy/` | TypeScript, Fastify 5, Drizzle | wendy.wozark.com | 3000 | Deployed |
| **Marty** | `wbot-marty/` | React 19, Vite, Tailwind v4, Flowbite | marty.wozark.com | 80 | Deployed |
| **Jonah** | `wbot-jonah/` | Python 3.12, FastAPI, GPT-5, LightGBM, Qdrant | internal only | 8000 | Deployed (V5) |

Each project has its own `CLAUDE.md` with detailed instructions. Open Claude in the specific project directory to work on it.

## Communication

```
Ruth → Wendy:  HTTP POST /signal (raw METAR + PWS data, auth: RUTH_SECRET)
Ruth → Jonah:  HTTP POST /signal (copy, JONAH_ENABLED toggle, fire-and-forget)
Jonah → Wendy: HTTP POST /prediction (advisory only — logged + broadcast, NO trade execution)
Wendy → Marty: WebSocket push (real-time events) + REST API (JWT auth)
Marty → Wendy: REST commands (buy, sell, settings) with JWT
Marty → Wendy → Jonah: POST /predictions/refresh/:station (manual refresh proxy)
```

**Internal (container-to-container):**
- Ruth → Wendy: `http://srv-captain--wendy:3000`
- Ruth → Jonah: `http://srv-captain--jonah:8000` (when JONAH_ENABLED=true)
- Wendy → DB: `srv-captain--wbot-db:5432`

**Public:**
- Marty → Wendy: `https://wendy.wozark.com` (browser, JWT auth)
- Marty WS → Wendy: `wss://wendy.wozark.com/ws`

## Database

- **Host:** `srv-captain--wbot-db:5432` (internal)
- **User:** postgres
- **Database:** wbot_prod
- **Tables:** metar_observations, trades, logs, app_config, auth_sessions

## Stations (9)

| Station | ICAO | Unit | PWS Coverage |
|---------|------|------|-------------|
| Seattle | KSEA | F | 3 PWS, 1.6km |
| Dallas | KDAL | F | 3 PWS, 1.9km |
| Chicago | KORD | F | 3 PWS, 0km |
| New York | KLGA | F | 3 PWS, 3.0km |
| Miami | KMIA | F | 3 PWS, 3.2km |
| Atlanta | KATL | F | 3 PWS, 3.7km |
| London | EGLC | C | 3 PWS, 1.6km |
| Paris | LFPG | C | 3 PWS, 2.5km |
| Toronto | CYYZ | C | 3 PWS, 7.8km |

## Signal Flow

```
1. Ruth polls NOAA every 3s → detects new METAR → POST /signal {type:"METAR"} to Wendy
2. Ruth polls WU API every 60s → captures 3 PWS per airport → POST /signal {type:"PWS"} to Wendy
3. Ruth also sends METAR signals to Jonah (fire-and-forget)
4. Jonah runs 5-source ensemble (LightGBM + Chronos + Open-Meteo + RAG + GPT-5) at dawn (6am local), then updates every 30min from 10am to peak_end
5. Jonah sends range prediction + timing signal (WAIT/SMALL/MEDIUM/STRONG) → POST /prediction to Wendy
6. Wendy receives METAR → updates running max → detects threshold crossing → evaluates guards → executes trade on CLOB
7. Wendy receives PWS → calculates anticipation (gap/conf/ramp) → if STRONG → executes anticipation BUY
8. Wendy broadcasts all events (including AI predictions) to Marty via WebSocket
9. Marty displays real-time: station cards, positions, logs, trace timelines, AI insights
```

## Anticipation Formula (PWS → predicted temperature)

```
T_pws       = median(PWS readings)
gap         = T_pws - T_metar
conf        = count(readings >= T_metar) / total
ramp        = linear regression of medians over last 10min
α           = station.pwsAlpha (0.5-0.8)
β           = 0.3
T_estimated = T_metar + (gap * conf * α) + (ramp * β)

STRONG:   gap > 2°F AND conf > 0.7 → BUY (never ROTATE on anticipation)
MODERATE: gap > 1°F AND conf > 0.6 → log alert only
WEAK:     ignore
```

## Trading Rules

- METAR is authority — only METAR triggers ROTATE
- ROTATE: BUY first, then SELL + harvest parallel (if BUY succeeds)
- PWS anticipation: BUY only (never ROTATE)
- Before 7am local → skip
- Gamma < 10% → skip, >= 75% → skip
- Book liquidity check before every trade
- Daily loss limit ($20 default)
- FOK verification via getOrder() + size_matched
- No stop-loss — hold until resolution
- DRY_MODE=true for testing (simulates CLOB)

## Deploy

Each project deploys independently via CapRover git push:

```
feat/xxx → staging → main (auto-deploy)
```

Updating Wendy doesn't affect Ruth or Marty. Updating Marty doesn't affect trading.

## Working with Projects

**To work on a specific project**, open Claude in its directory:
```bash
cd ~/personal/wozark/wbot-ruth    # Sensor (Rust)
cd ~/personal/wozark/wbot-wendy   # Brain (TypeScript)
cd ~/personal/wozark/wbot-marty   # Dashboard (React)
```

Each has its own CLAUDE.md with complete context.

**To orchestrate across projects** (integration issues, API contracts), work from this master directory (`~/personal/wozark/`).

## API Contract (Wendy endpoints)

| Method | Endpoint | Auth | Returns |
|--------|----------|------|---------|
| GET | /health | None | `{status, trading, dryMode, noHarvest}` |
| POST | /auth/login | None | `{token}` (JWT) |
| GET | /auth/status | JWT | `{authenticated}` |
| GET | /stations?pool=0 | JWT | StationData[] with buckets, positions, timeline |
| GET | /positions | JWT | `{positions[], summary}` formatted |
| GET | /balance | JWT | USDC balance |
| GET | /settings | JWT | `{trading, noHarvest, amountPerTrade, maxDailyLoss}` |
| POST | /settings | JWT | Updates config |
| GET | /stations/toggles | JWT | StationToggle[] with enabled + pwsAlpha |
| POST | /stations/toggles | JWT | Save enabled stations |
| GET | /logs?limit=100 | JWT | LogEntry[] formatted with time/type/source |
| GET | /logs/trace/:id | JWT | LogEntry[] for trace timeline |
| POST | /buy | JWT | `{station, bucket, side, amount}` → Wendy resolves tokenId |
| POST | /sell | JWT | `{station, tokenId, shares}` |
| POST | /signal | RUTH_SECRET | Raw METAR or PWS from Ruth |
| GET | /stations/config | RUTH_SECRET | Station list for Ruth polling |
| WS | /ws?token=JWT | JWT | Real-time push events |

## Critical Rules

- `.env` = connections and credentials ONLY. Trading config in DB.
- NEVER improvise CLOB code — study SDK source first
- DB writes are fire-and-forget in trading hot path
- Show city names in UI, never ICAO codes
- Log only trades/rotates/gains/losses, no spam
- Always pg_dump before destructive DB operations

## Specs and Plans

- Architecture spec: `wbot-wendy/docs/2026-03-23-v5-architecture-design.md`
- Ruth plan: `wbot-ruth/docs/plans/2026-03-23-ruth-implementation.md`
- Wendy plan: `wbot-wendy/docs/plans/2026-03-23-wendy-implementation.md`
- Marty plan: `wbot-marty/docs/plans/2026-03-23-marty-implementation.md`


## Workflow Orchestration

### 1. Plan Node Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If blocked for more than 2 attempts, surface to user — don't loop silently

### 2. Subagent Strategy
- Use subagents liberally to keep main context window clean
- One task per subagent for focused execution

### 3. Self-Improvement Loop
- After ANY correction from the user: update lessons
- Review lessons at session start

### 4. Verification Before Done
- Never mark a task complete without proving it works
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance (Balanced)
- Skip for simple fixes — don't over-engineer
- If fix touches >3 files or requires workaround, pause and re-evaluate

### 6. Autonomous Bug Fixing
- Trivial bugs: fix immediately
- Non-trivial: plan first
- If you can state root cause in one sentence, it's trivial

## Core Principles

- **Simplicity First**: fewer moving parts, easier to delete
- **No Laziness**: root causes, no TODOs, no dead code
- **Minimal Impact**: only touch what's necessary
- **Explicit over Implicit**: name assumptions before acting
- **Fail Loudly**: obvious errors, visible in logs

## User preferences

- Language: English (UI and code)
- Timezone: BRT (America/Sao_Paulo)
- No over-engineering
- Delete unused code, never keep dead code
- Always consult memory before making assumptions
