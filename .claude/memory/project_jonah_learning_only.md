---
name: Jonah learning-only mode
description: Jonah does NOT fire /trigger for 3 months (2026-04-14 → 2026-07-14+). Only /prediction advisory.
type: project
originSessionId: 54765d79-9fc7-4875-ad6e-18a50dbd3ce1
---

Jonah is in LEARNING-ONLY mode since 2026-04-14 for at least 3 months. Never describe Jonah trigger behavior as active.

- **Hard block**: `TRIGGER_ENABLED = False` hardcoded at `wbot-jonah/src/proxy.py:26`. All /trigger calls return early.
- **Health check**: `GET /health` returns `"mode": "learning"`.
- **What IS active**: `/prediction` POST to Wendy (advisory — logged, broadcast to Marty). PWS + METAR ingestion. Full ensemble pipeline. Nightly learning loop resolves outcomes to Qdrant RAG.
- **What is NOT active**: no /trigger calls, no Jonah-initiated trades, no SELL triggers. Wendy's `/trigger` endpoint exists but is never called.
- **In Wendy's signal.service.ts**: `jonahTokenId = state.lastTokenId` is always null. Wendy runs in pure METAR trading mode — BUY on crossings, skip on confirmedBuckets, ROTATE UP if bucket rises.

**Why:** Accumulate real outcomes in Qdrant (~18k points currently) to calibrate the ensemble before resuming execution. Also Tales is focused on structural cleanup (Synoptic-first, Marty rewrite) rather than tuning trade execution.

**How to apply:**

- Before describing the trading flow or signal path, confirm this mode is still active (check `proxy.py:26`).
- Do not invent trigger behavior in docs or memory.
- When user reports trades NOT happening from Jonah — that's correct/expected, not a bug.
- To resume trading: flip `TRIGGER_ENABLED = True`, review accuracy metrics, update all CLAUDE.md docs.
