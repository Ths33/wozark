---
name: Wozark V5 Project State
description: Weather auto-trading system for Polymarket. Wendy operates solo. Jonah in learning mode (disconnected from trading).
type: project
---

Wozark is a weather temperature auto-trading system for Polymarket, consisting of 4 deployed projects:

- **Ruth** (Rust/Axum) — Pure sensor polling NOAA METAR (3s) + Weather Underground PWS (60s). Enriched payloads: full METAR (temp, dewpoint, humidity, wind, clouds, pressure, 6h max, raw) + PWS (temp, solar radiation, UV, wind). Deployed.
- **Wendy** (TypeScript/Fastify 5/Drizzle) — Trading brain operating independently. METAR threshold + PWS anticipation (strict: score ≥0.70, 20min-before-METAR window, max 1 bucket jump). Persists running max across restarts. Jonah predictions logged but NOT executed. Deployed.
- **Marty** (React 19/Vite/Tailwind v4/Flowbite) — Real-time operations dashboard SPA. Insights page shows Jonah predictions (display only). Deployed.
- **Jonah** (Python/FastAPI) — AI analyst in **LEARNING MODE**. Predicts but does NOT trade. Stores every prediction in `predictions` table. Learning loop compares vs actual METAR max. Receives full Ruth payload (METAR history + PWS solar/UV). ~$15/month.

**Infrastructure:** CapRover on VPS (168.231.70.56), PostgreSQL (srv-captain--wdb:5432), Qdrant (srv-captain--qdrant:6333), 9 weather stations (6 US, 2 EU, 1 Canada). Deploy = push to main.

## Current State (2026-03-25)

- **Wendy trades alone** — METAR is primary, PWS anticipation with strict guards
- **Jonah observes** — predictions stored, accuracy tracked, no trade authority
- **Reconnection criteria:** Jonah >70% accuracy over 5+ consecutive days

## PWS Trading Rules
- Entry: STRONG score (≥0.70) + bucket margin (≥0.3°F) + 20min before METAR window + max 1 bucket above current + no active anticipation
- Hold: always (no stop-loss)
- Exit: only ROTATE (new METAR max) or manual sell

## Monitor
- Duplicate detection by station:tokenId (not station alone)
- Verifies position exists before sell retry
- Terminal errors (balance/allowance) stop immediately

## Resolved Issues
- Position sync: Wendy reconciles with real CLOB positions (detects external buys/sells)
- Running max persisted across restarts (queries today's max METAR + traded buckets from DB)
- Monitor duplicate fix: groups by tokenId, terminal error handling
- Jonah °C single values (not ranges)
- PWS log noise reduced (dedup every 10min)
