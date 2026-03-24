# Wozark — Weather Auto-Trading System

Polymarket weather temperature auto-trading system. Captures real-time weather data, makes trading decisions, and provides an operations dashboard.

## Architecture

```
Ruth (Rust/Axum)       Wendy (TypeScript/Fastify)      Marty (React/Vite)       Jonah (Python/FastAPI)
Sensor                 Brain                            Dashboard                Analyst
├─ METAR 3s poll       ├─ Threshold detection           ├─ Station cards          ├─ Claude Haiku LLM
├─ PWS 60s poll        ├─ Trading guards                ├─ Positions + P&L        ├─ METAR-triggered analysis
└─ POST → Wendy+Jonah  ├─ CLOB execution (buy/sell)     ├─ Logs + trace timeline  ├─ Qdrant RAG (optional)
                       ├─ PWS anticipation formula      ├─ Settings + toggles     └─ Advisory predictions
                       ├─ WebSocket push → Marty        └─ Manual buy/sell
                       └─ PostgreSQL logging
```

## Repos

| Project | Repo | Stack |
|---------|------|-------|
| **This repo** | [Ths33/wozark](https://github.com/Ths33/wozark) | Orchestration, memory, architecture docs |
| **Ruth** | [Ths33/ruth](https://github.com/Ths33/ruth) | Rust, Axum, Tokio |
| **Wendy** | [Ths33/wendy](https://github.com/Ths33/wendy) | TypeScript, Fastify 5, Drizzle |
| **Marty** | [Ths33/marty](https://github.com/Ths33/marty) | React 19, Vite, Tailwind v4, Flowbite |
| **Jonah** | [Ths33/jonah](https://github.com/Ths33/jonah) | Python 3.12, FastAPI, Claude Haiku, Qdrant |

## Setup on a new machine

### 1. Clone all repos

```bash
mkdir -p ~/personal/wozark && cd ~/personal/wozark

# Master repo (this one)
git clone git@github.com:Ths33/wozark.git .

# Subprojects
git clone git@github.com:Ths33/ruth.git wbot-ruth
git clone git@github.com:Ths33/wendy.git wbot-wendy
git clone git@github.com:Ths33/marty.git wbot-marty
git clone git@github.com:Ths33/jonah.git wbot-jonah
```

### 2. Link Claude Code memory

The `.claude/memory/` directory contains shared AI context (project state, decisions, user preferences) that persists across Claude Code sessions. Link it so Claude Code finds it automatically:

```bash
# Create the Claude Code project config directory
# The folder name is derived from the absolute path: / → -
# Example: /home/tales/personal/wozark → -home-tales-personal-wozark
# Adjust this path to match YOUR machine's absolute path

WOZARK_PATH=$(pwd | sed 's|/|-|g; s|^-||')
mkdir -p ~/.claude/projects/-${WOZARK_PATH}/
ln -s "$(pwd)/.claude/memory" ~/.claude/projects/-${WOZARK_PATH}/memory
```

Verify it works:
```bash
ls ~/.claude/projects/-${WOZARK_PATH}/memory/
# Should show: MEMORY.md, project_overview.md, project_jonah.md, etc.
```

### 3. Install dependencies

```bash
# Wendy
cd wbot-wendy && npm install && cd ..

# Marty
cd wbot-marty && npm install && cd ..

# Ruth (needs Rust toolchain)
cd wbot-ruth && cargo build && cd ..
```

### 4. Environment variables

Each subproject needs its own `.env`. These are NOT committed (secrets). Ask the project owner or check CapRover for production values.

- `wbot-wendy/.env` — DATABASE_URL, POLY_*, JWT_SECRET, RUTH_SECRET
- `wbot-ruth/.env` — WENDY_URL, RUTH_SECRET, WU_API_KEY, JONAH_ENABLED, JONAH_URL
- `wbot-marty/.env` — VITE_WENDY_URL, VITE_WENDY_WS_URL
- `wbot-jonah/.env` — RUTH_SECRET, ANTHROPIC_API_KEY, WENDY_URL, QDRANT_HOST (optional), DATABASE_URL (optional)

## Production

- **CapRover panel:** https://captain.wozark.com/
- **VPS:** 168.231.70.56 (Brazil East Coast)
- **Deploy:** Each project auto-deploys on push to `main` via CapRover git webhook

| Service | URL | Internal hostname |
|---------|-----|-------------------|
| Wendy | https://wendy.wozark.com | srv-captain--wendy:3000 |
| Marty | https://marty.wozark.com | — (static SPA) |
| Ruth | internal only | srv-captain--ruth:8080 |
| Jonah | internal only | srv-captain--jonah:8000 |
| DB | internal only | srv-captain--wbot-db:5432 |

## Working with Claude Code

Open Claude Code in the specific project directory to work on it:

```bash
cd ~/personal/wozark              # Cross-project orchestration
cd ~/personal/wozark/wbot-ruth    # Sensor work
cd ~/personal/wozark/wbot-wendy   # Trading brain work
cd ~/personal/wozark/wbot-marty   # Dashboard work
cd ~/personal/wozark/wbot-jonah   # AI analyst work
```

Each project has its own `CLAUDE.md` with detailed context. The master `CLAUDE.md` in this repo covers the full system architecture.

## Stations (9)

| Station | ICAO | Unit | Location |
|---------|------|------|----------|
| Seattle | KSEA | °F | US West |
| Dallas | KDAL | °F | US South |
| Chicago | KORD | °F | US Central |
| New York | KLGA | °F | US East |
| Miami | KMIA | °F | US Southeast |
| Atlanta | KATL | °F | US Southeast |
| London | EGLC | °C | UK |
| Paris | LFPG | °C | France |
| Toronto | CYYZ | °C | Canada |
