# Changelog

All notable changes to the Wozark system. Covers all 4 services: Ruth, Wendy, Marty, Jonah.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Commits follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

## [Unreleased]

### Changed

- **Wendy**: Conventional commits enforced globally across all projects

## [2026-04-16] — Jonah Learning-Only Lockdown

### Removed

- **Wendy**: POST /trigger endpoint deleted entirely (~300 lines, 8 service dependencies)
- **Wendy**: AI trade-execution code: `evaluateAiGates`, `decideAiTrade`, `TriggerSchema`, `gates.ts`
- **Wendy**: Dead DB queries: `saveJonahTrigger`, `getLatestJonahTrigger`

### Fixed

- **Wendy**: Shadow mode binary toggle — `SHADOW_MODE=true` hard-disables real trading across all entry points

## [2026-04-15] — Shadow Mode + Critical Fixes

### Added

- **Wendy**: Shadow (dry) trading module — 15-day validation, decoupled by env var
- **Ruth**: Hot-poll window (:50-:58 at 3s interval) while T-group missing
- **Ruth**: Parallel TGFTP fetch to close Synoptic propagation gap on hourly slots
- **Wendy**: Sustained AUTO crossing logic — accepts bucket threshold after 3 consecutive readings
- **Wendy**: Heartbeat log showing current T-group value every 5min

### Fixed

- **Wendy**: Border zone guard uses `runningMaxC` instead of `signal.tempC`
- **Wendy**: Daily loss cap uses station local timezone instead of UTC
- **Wendy**: Per-station queue serializes `processMetar` calls — prevents double-BUY race condition

### Changed

- **Wendy**: `processMetar` refactored into testable subfunctions (no behavior change)
- **Wendy**: Market-flow ROTATE feature reverted and removed (price consultative, not reactive)
- **Jonah**: POST /trigger disabled — Jonah enters learning-only mode for 3+ months

## [2026-04-08] — Synoptic Maturity + Imprecise Handling

### Added

- **Wendy**: Hide imprecise (AUTO) readings from UI while still tracking internally
- **Wendy**: `temp_precise` persistence + auto-heal poisoned `runningMaxC` on boot
- **Wendy**: Cold-day re-eval for unconfirmed buckets
- **Wendy**: 99c auto-sell for near-expired positions
- **Wendy**: `lastPreciseTempC` exposed for UI — NOW matches bucket system

### Fixed

- **Wendy**: Rate-limit exemption for internal traffic (`x-internal-secret`)
- **Wendy**: METAR source vs freshness tracked separately
- **Wendy**: `ceiling_ft` column added via idempotent migration

### Changed

- **Wendy**: P1+P2 latency optimizations on signal hot path (400-700ms down to 150-400ms)
- **Wendy**: Book snapshot cache TTL raised from 10s to 30s (95%+ hit rate)

## [2026-03-28] — Synoptic-First Architecture

### Added

- **Ruth**: Synoptic Data as primary METAR source, TGFTP as fallback
- **Ruth**: `/timeseries?recent=10` + slot scheduler `[:00,:05,...,:50,:53,:55]`
- **Ruth**: Per-station retry (3 attempts with backoff) before TGFTP fallback
- **Ruth**: 6-token Synoptic API key rotation on failure
- **Ruth**: `source` field in MetarSignal (synoptic/tgftp)
- **Ruth**: `air_temp_max_1hr` + pressure from Synoptic vars
- **Wendy**: GET `/metar/:station/history` for station chart data
- **Wendy**: `ceiling_ft` in METAR signal, schema, and queries
- **Marty**: Bento home layout with Recharts, hover tooltips, unified logs
- **Marty**: Everforest dark theme, Manrope font, BRT timezone everywhere
- **Marty**: Station detail page with Polymarket link, raw METAR copy, Jonah chart
- **Jonah**: Learning-only mode with Synoptic timing accuracy tracking
- **Jonah**: LightGBM + Chronos + Open-Meteo ensemble with GPT-5 final decision
- **Jonah**: Claude Sonnet fallback when GPT-5 quota is exhausted

### Fixed

- **Ruth**: Fresh sensor data for trade trigger, not hourly METAR string
- **Ruth**: Cold-start filter prevents 24-obs boot flood
- **Ruth**: VRB wind direction parsing (`VRB03KT` -> speed=3, dir=variable)
- **Ruth**: US altimeter pressure parsing (`A3014` -> 1020 hPa)
- **Wendy**: WebSocket `new_metar` triggers full refetch in Marty
- **Marty**: NaN guard in portfolio, sparkline, and station positions

### Removed

- **Wendy**: Anticipation service, `maxTempC6h`, PWS signal path
- **Ruth**: Dead helpers from Synoptic parser

## [2026-03-23] — Initial Release

### Added

- **Ruth**: Rust/Axum METAR sensor polling 10 US stations
- **Wendy**: TypeScript/Fastify trading brain with CLOB execution
- **Marty**: Next.js 16 dashboard
- **Jonah**: Python/FastAPI learning analyst with Qdrant RAG
- 4 services deployed on CapRover (Helsinki)
- Internal auth via `x-internal-secret` header
- FOK + GTC fallback order execution
- WebSocket real-time updates to dashboard
