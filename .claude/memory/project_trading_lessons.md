---
name: Trading architecture lessons
description: Key decisions and lessons learned about the trading system design
type: project
originSessionId: 6fbec674-b981-4501-b7e4-315eaee889f9
---

- **FOK fill verification**: Never trust `success: true` — always verify via `getOrder().size_matched`
- **Running max never descends**: `Math.max(prev, new)` only, reset on day change. Only advances from real METAR `tempC` — never from derived fields.
- **METAR confirmative**: Wendy BUYs on every threshold crossing. When `jonahTokenId = null` (current state), Wendy is in pure METAR mode: BUY on first crossing, HOLD same bucket, BUY/ROTATE if bucket rises.
- **Jonah is LEARNING-ONLY (2026-04-14+)**: No triggers for at least 3 months. `/trigger` endpoint exists in Wendy but Jonah does not call it. `jonahTokenId` is always null. Do not describe Jonah trigger behavior as active.
- **Jonah trigger path (dormant)**: When/if triggers resume — Jonah fires at ≥70% confidence, Wendy does SKIP if same bucket already held, ROTATE if higher bucket. For now, irrelevant.
- **ROTATE = BUY first**: Never sell before the new BUY succeeds
- **max1hC removed (2026-04-14)**: `maxTempC6h` / `max_temp_1h_c` was a fake Synoptic rolling max (2 readings, not 1h). Removed entirely. Root cause of KHOU 84°F phantom max bug.
- **Synoptic as primary METAR source (2026-04-14)**: Ruth fetches `/latest?within=120&vars=...,metar`. Parses `metar_set_1` for full METAR (cloud layers, SM visibility, ceiling, wx_string). Falls back to TGFTP if Synoptic down.
- **Synoptic token**: `7c76618b66c74aee913bdbae4b448bdd` — requires Referer/Origin weather.gov headers, max 5 stations per batch

**Why:** Learned from V4 phantom fills, duplicate trades, missed entries, and 2026-04-14 KHOU phantom max loss.
**How to apply:** Always follow these patterns when modifying trading logic. Never assume Jonah triggers are active without confirming.
