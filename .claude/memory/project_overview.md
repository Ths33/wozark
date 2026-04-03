---
name: Wozark V5 Project State
description: Weather auto-trading system for Polymarket. Jonah-gated METAR execution, pre-METAR predictions, intraday learning. 10 US-only stations.
type: project
---

Wozark is a weather temperature auto-trading system for Polymarket, consisting of 4 deployed projects:

- **Ruth** (Rust/Axum) — Sensor polling NOAA METAR (adaptive 3-60s) + Weather Underground PWS (5min). Fetches station list from Wendy dynamically. US altimeter pressure parsing (A-group), VRB wind parsing. Deployed.
- **Wendy** (TypeScript/Fastify 5/Drizzle) — Trading brain. METAR observe-only mode (logs threshold, waits for Jonah pre_metar confirmation via metarTradingEnabled gate). Jonah /trigger is primary trade executor. PWS anticipation (strict). CLOB API wrapper with dynamic fee/tickSize/negRisk. Proxies Jonah learning endpoints. Kill switch (tradingEnabled). Deployed.
- **Marty** (React 19/Vite/Tailwind v4/shadcn) — Mobile-first dashboard. Learning monitor with accuracy trends + source errors. Jonah heartbeat status. Feed state (live/fallback/missing) per station. Intraday learning audit. Admin learning controls. Dual timezone (local + Brasília). Deployed.
- **Jonah** (Python/FastAPI) — AI analyst with trade authority. 4-source ensemble (LightGBM, Chronos, Open-Meteo, RAG) + GPT-5 final decision-maker. Pre-METAR predictions (~5min before next METAR). Intraday drift learning in RAG. Nightly learning loop with per-source error tracking. Fires POST /trigger to Wendy. Bucket output canonicalized to even-odd market format. Deployed (V5).

**Infrastructure:** CapRover on VPS (168.231.70.56), PostgreSQL, Qdrant (srv-captain--qdrant:6333), 10 US-only weather stations (all °F). Deploy = push to main.

## Current State (2026-04-03)

- **Wendy METAR observe-only** — logs threshold crossing, waits for Jonah pre_metar confirmation (metarTradingEnabled gate, 20min age limit)
- **Jonah fires trades** — POST /trigger with timing thresholds 30/40/55%, supports BUY and upward ROTATE
- **Pre-METAR predictions** — 55min cycle, fires ~5min before expected METAR, records crossing + non-crossing
- **Intraday drift learning** — RAG learns drift-after-correct patterns, per-source errors, pre-METAR accuracy
- **tradingEnabled** is absolute kill switch — blocks ALL orders in BuyService + SellService
- **95%+ confidence** can bypass early trading window
- **Price floor** 5c, ceiling 75%
- **FOK → GTC fallback** for delayed orders

## Key Features
- PayloadCache: static payloads loaded at startup, fresh book fetched at trigger time
- Dynamic CLOB params: feeRateBps, tickSize, negRisk fetched per market
- Threshold detection only fires upward (not on temperature drops)
- GPT-5 bucket canonicalization: two-stage normalization to valid even-odd market pairs
- Phase normalization: dawn→briefing, update→peak_update
- Board weather summaries: feed state (live/fallback/missing) with age metadata
- Heartbeat per station: healthy/waiting/stale/missing with cadence info
- Learning endpoints proxied: /learning/metrics, /learning/run, /learning/debug
- Position dust filter by value (< $0.01)

## Monitor
- Duplicate detection by station:tokenId (not station alone)
- Verifies position exists before sell retry
- Terminal errors (balance/allowance) stop immediately
- Respects tradingEnabled kill switch
