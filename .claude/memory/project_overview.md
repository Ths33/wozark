---
name: Wozark V5 Project State
description: Weather auto-trading system for Polymarket with 4 services (Ruth/Wendy/Marty active, Jonah implemented awaiting deploy)
type: project
---

Wozark is a weather temperature auto-trading system for Polymarket, consisting of 4 projects:

- **Ruth** (Rust/Axum) — Pure sensor polling NOAA METAR (3s) + Weather Underground PWS (60s). Has JONAH_ENABLED toggle for dual signal delivery. Deployed.
- **Wendy** (TypeScript/Fastify 5/Drizzle) — Trading brain with all business logic, CLOB execution, WebSocket push. Deployed. Recent fixes: disabled PWS_EXIT auto-sell, added log dedup, added portfolio sync, skip resolved markets.
- **Marty** (React 19/Vite/Tailwind v4/Flowbite) — Real-time operations dashboard SPA. Deployed. Has 30s polling fallback.
- **Jonah** (Python/FastAPI) — AI analyst for daily max temperature prediction. Implemented, repo on GitHub, NOT YET DEPLOYED. Decoupled advisory mode — disabling has zero impact on trading.

**Why:** Trading weather temperature markets on Polymarket using real-time METAR data for authoritative signals and PWS data for anticipation/edge.

**How to apply:** Each project is independent with its own git repo, CLAUDE.md, and deploy pipeline. Work on specific projects by cd-ing into their directory. Cross-project work (API contracts, integration) happens from the master wozark/ directory.

Infrastructure: CapRover on VPS 168.231.70.56, PostgreSQL internal, 9 weather stations (6 US, 2 EU, 1 Canada). Deploy = push to main (GitHub webhook triggers CapRover auto-deploy).

## Known Issues (2026-03-24)

- ROTATE sells positions that were already manually closed on Polymarket ("not enough balance/allowance")
- Harvest during ROTATE can act against existing positions (buys NO on bucket where we have YES)
- Bot acts on stale internal state when user trades manually on Polymarket — portfolio sync (3min) helps but doesn't cover ROTATE moment
- PWS has systematic upward bias (2-4°F above METAR) — buys waypoint buckets instead of predicted daily max
- Multiple buys/sells on same bucket within minutes (Chicago 48-49 today)
