---
name: Wozark Project Overview
description: Wozark weather auto-trading system — 4 services, CapRover deployment
type: project
originSessionId: 6fbec674-b981-4501-b7e4-315eaee889f9
---

Weather temperature auto-trading system for Polymarket. 4 services:

- **Ruth** (Rust/Axum) — sensor, polls weather data, sends to Wendy+Jonah
- **Wendy** (TypeScript/Fastify) — brain, trading decisions, CLOB execution
- **Marty** (React/Next.js) — dashboard, real-time via WebSocket
- **Jonah** (Python/FastAPI) — AI analyst, ensemble predictions, GPT-5

**Deploy:** CapRover at captain.wozark.com — git push to main auto-deploys.
Each project has its own git repo. Internal auth via `x-internal-secret` header.

**Why:** Captures inefficiencies in Polymarket temperature markets using real-time weather data + AI ensemble predictions.
**How to apply:** When making cross-service changes, update all affected repos and deploy in dependency order (Ruth → Wendy → Marty).
