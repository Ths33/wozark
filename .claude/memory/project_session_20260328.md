---
name: project_session_20260328
description: Massive session summary — CLOB improvements, Jonah fixes, Marty redesign, 10 US stations, security fixes
type: project
---

## Session 2026-03-28 — Major Changes

### Backend (Wendy)
- CLOB API wrapper (price, midpoint, spread, fee-rate, tick-size)
- PayloadCache: static payloads at startup, fresh book on trigger
- POST /trigger endpoint: Jonah fires trades directly
- Kill switch: tradingEnabled=false blocks ALL orders (BuyService + SellService + Monitor)
- Order verify fast-path: FOK matched = instant (5.7s → ~1s)
- Spread guard (> 6c = skip)
- Dynamic feeRateBps/tickSize/negRisk (no hardcode)
- External trades logged (signalType=EXTERNAL)
- Threshold only fires upward (not on temp drops)
- lastBucket tracks temperature only (not positions)
- Double buy fix: PWS confirmed → adds to confirmedBuckets
- /trigger supports ROTATE
- US altimeter pressure parsing (A-group)
- VRB wind parsing
- Position dust filter by value (< $0.01)
- WS broadcasts full METAR + PWS payloads + live logs
- Security: fail-closed secret comparison, no default password, CORS restricted, timing-safe

### Backend (Jonah)
- Fix: metarRaw field name
- Fix: numpy float64 serialization
- Fix: learning.py observed_at → valid_utc
- Fix: prediction push payload format
- Fix: range detection uses only Polymarket even-odd buckets
- GPT-5 enabled in rapid mode
- Fires POST /trigger when timing MEDIUM/STRONG

### Backend (Ruth)
- Jonah delivery logging
- US altimeter pressure parsing
- VRB wind direction parsing

### Frontend (Marty)
- Complete redesign: mobile-first shadcn + Tailwind + Chart.js
- Station detail: grid layout (hero+conditions, PWS+chart, timeline, market+positions, live logs)
- Real-time via WS: METAR/PWS push to Zustand store → React reactive
- Live logs streaming with green pulse indicator
- Live clock per station timezone
- Breadcrumbs on all pages

### Infrastructure
- 10 US-only stations (removed Toronto, London, Paris, Denver)
- New: Los Angeles, San Francisco, Austin, Houston
- PWS fixes: KLGA, KMIA, KATL, KORD, EGLC, KSEA
- Database schema doc: docs/database-schema.md
- Security review: 4 critical fixed, 6 high documented

### Still TODO for next session
- H1: JWT in httpOnly cookies instead of localStorage
- H2: Rate limiting on login/trading endpoints
- H3: Jonah endpoints need auth (or restrict to internal network)
- H4: Separate secrets per service
- Station detail: market/positions don't update via WS yet (need Wendy broadcast)
- Timeline chart doesn't grow with new METARs (needs store accumulation)
- Consider adding more chart types per user request
