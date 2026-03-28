---
name: Wozark V5 Project State
description: Weather auto-trading system for Polymarket. Jonah fires /trigger to Wendy for AI-driven trades. 10 US-only stations.
type: project
---

Wozark is a weather temperature auto-trading system for Polymarket, consisting of 4 deployed projects:

- **Ruth** (Rust/Axum) — Sensor polling NOAA METAR (adaptive 3-60s) + Weather Underground PWS (5min). Fetches station list from Wendy dynamically. US altimeter pressure parsing (A-group), VRB wind parsing. Deployed.
- **Wendy** (TypeScript/Fastify 5/Drizzle) — Trading brain. METAR threshold (upward only) + PWS anticipation + Jonah /trigger execution. CLOB API wrapper with dynamic fee/tickSize/negRisk. PayloadCache for static data. Spread guard (>6c = skip). Kill switch (tradingEnabled). FOK fast-path verification. Deployed.
- **Marty** (React 19/Vite/Tailwind v4/shadcn) — Mobile-first dashboard. Station detail with METAR conditions, PWS readings, anticipation. Per-station logs. Breadcrumb navigation. Auto-refresh (positions 30s, stations 60s). /data/:station raw data view. Deployed.
- **Jonah** (Python/FastAPI) — AI analyst with trade authority. 5-source ensemble (LightGBM, Chronos, Open-Meteo, RAG, GPT-5). Fires POST /trigger to Wendy when timing is MEDIUM/STRONG (confidence >= 70%). GPT-5 enabled in rapid mode. Deployed (V5).

**Infrastructure:** CapRover on VPS (168.231.70.56), PostgreSQL, Qdrant (srv-captain--qdrant:6333), 10 US-only weather stations (all °F). Deploy = push to main.

## Current State (2026-03-28)

- **Wendy handles METAR threshold + PWS anticipation + Jonah /trigger**
- **Jonah fires trades** — POST /trigger when confidence >= 70%, supports BUY and ROTATE
- **tradingEnabled** is absolute kill switch — blocks ALL orders in BuyService + SellService
- **External trades** logged to DB (signalType=EXTERNAL)

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
