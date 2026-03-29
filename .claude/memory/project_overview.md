---
name: Wozark V5 Project State
description: Weather auto-trading system for Polymarket. Jonah fires /trigger to Wendy for AI-driven trades. 10 US-only stations.
type: project
---

Wozark is a weather temperature auto-trading system for Polymarket, consisting of 4 deployed projects:

- **Ruth** (Rust/Axum) — Sensor polling NOAA METAR (adaptive 3-60s) + Weather Underground PWS (5min). Fetches station list from Wendy dynamically. US altimeter pressure parsing (A-group), VRB wind parsing. Deployed.
- **Wendy** (TypeScript/Fastify 5/Drizzle) — Trading brain. METAR threshold (upward only) + Jonah /trigger execution. PWS data buffered and fed to Jonah (no autonomous PWS trading). CLOB API wrapper with dynamic fee/tickSize/negRisk. PayloadCache for static data. Kill switch (tradingEnabled). FOK fast-path + GTC fallback. Deployed.
- **Marty** (React 19/Vite/Tailwind v4/shadcn) — Mobile-first dashboard. Station detail with METAR conditions, PWS readings. Per-station logs. Breadcrumb navigation. Auto-refresh (positions 30s, stations 60s). /data/:station raw data view. Deployed.
- **Jonah** (Python/FastAPI) — AI analyst with trade authority. 4-source ensemble (LightGBM, Chronos, Open-Meteo, RAG) + GPT-5 independent pre-METAR predictor. Fires POST /trigger to Wendy based on timing thresholds (30/40/55%). Deployed (V5).

**Infrastructure:** CapRover on VPS (168.231.70.56), PostgreSQL, Qdrant (srv-captain--qdrant:6333), 10 US-only weather stations (all °F). Deploy = push to main.

## Current State (2026-03-29)

- **Wendy handles METAR threshold + Jonah /trigger** (PWS is data-only, feeds Jonah)
- **Jonah fires trades** — POST /trigger with timing thresholds 30/40/55%, supports BUY and upward ROTATE (downward ROTATE blocked)
- **tradingEnabled** is absolute kill switch — blocks ALL orders in BuyService + SellService
- **External trades** logged to DB (signalType=EXTERNAL)
- **Price floor** 5c (was 20c), ceiling 75%
- **FOK → GTC fallback** for delayed orders
- **Spread guard removed** — no longer needed

## Key Features
- PayloadCache: static payloads loaded at startup, fresh book fetched at trigger time
- Dynamic CLOB params: feeRateBps, tickSize, negRisk fetched per market
- Threshold detection only fires upward (not on temperature drops)
- lastBucket tracks temperature only (not positions)
- Position dust filter by value (< $0.01)
- /system/status includes Jonah DB health

## Monitor
- Duplicate detection by station:tokenId (not station alone)
- Verifies position exists before sell retry
- Terminal errors (balance/allowance) stop immediately
- Respects tradingEnabled kill switch
