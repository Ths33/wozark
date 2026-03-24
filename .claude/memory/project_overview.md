---
name: Wozark V5 Project State
description: Weather auto-trading system for Polymarket with 3 independent services (Ruth/Wendy/Marty) deployed on CapRover VPS
type: project
---

Wozark is a weather temperature auto-trading system for Polymarket, consisting of 4 projects (3 active + 1 planned):

- **Ruth** (Rust/Axum) — Pure sensor polling NOAA METAR (3s) + Weather Underground PWS (60s). Has git repo with commits, deployable.
- **Wendy** (TypeScript/Fastify 5/Drizzle) — Trading brain with all business logic, CLOB execution, WebSocket push. Has git repo with commits, actively developed.
- **Marty** (React 19/Vite/Tailwind v4/Flowbite) — Real-time operations dashboard SPA. Has git repo with commits, actively developed.
- **Jonah** (planned) — AI analyst for daily max temperature prediction. Enables strategic entry on correct bucket before market prices it in. See project_jonah.md.

**Why:** Trading weather temperature markets on Polymarket using real-time METAR data for authoritative signals and PWS data for anticipation/edge.

**How to apply:** Each project is independent with its own git repo, CLAUDE.md, and deploy pipeline. Work on specific projects by cd-ing into their directory. Cross-project work (API contracts, integration) happens from the master wozark/ directory.

Infrastructure: CapRover on VPS 168.231.70.56, PostgreSQL internal, 9 weather stations (6 US, 2 EU, 1 Canada).
