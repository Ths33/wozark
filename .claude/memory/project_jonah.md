---
name: Project Jonah - AI Weather Analyst
description: 4th service (Python/FastAPI) for AI-powered daily max prediction. Implemented, awaiting deploy. Decoupled advisory — zero impact if disabled.
type: project
---

Jonah is the 4th service in the Wozark architecture — an AI analyst that predicts daily maximum temperatures. **Implemented and on GitHub, NOT YET DEPLOYED.**

**Repo:** git@github.com:Ths33/jonah.git
**Stack:** Python 3.12, FastAPI, Anthropic SDK (Claude Haiku), Qdrant (optional), APScheduler
**Cost:** ~$0.40/day (~$12/month) with Haiku

**Why:** PWS anticipation predicts the "next bucket" (short-term), not the daily max. This leads to buying waypoint buckets (e.g., 80-81°F at 11am Miami) instead of the likely max (83-84°F).

**Architecture (decoupled advisory):**
```
Ruth → Wendy  (direct, unchanged, always works)
Ruth → Jonah  (copy, JONAH_ENABLED=true/false toggle)
       Jonah → Wendy POST /prediction (advisory push, not yet implemented on Wendy side)
```

**How it works:**
- METAR arrival triggers LLM analysis (non-blocking, ~1s)
- PWS readings buffer between METARs for richer context
- Mid-interval re-analysis only if PWS trend shifts >1°C
- Nightly learning loop: compare predictions vs results → store in Qdrant
- Signal forwarding NEVER blocks on LLM

**Deploy requirements:**
- CapRover app `jonah`
- Qdrant via Docker image `qdrant/qdrant` (optional, for learning loop)
- Envs: RUTH_SECRET, ANTHROPIC_API_KEY, WENDY_URL (minimum)
- Ruth: set JONAH_ENABLED=true, JONAH_URL=http://srv-captain--jonah:8000

**Still needed:**
- Wendy: POST /prediction endpoint to receive Jonah's predictions
- Wendy: use prediction in bucket decision logic instead of raw PWS estimate

## Backlog

1. **Daily max prediction** — AI predicts which bucket will be the daily high, enabling entry before market prices it in. Uses: time of day, peak time, humidity, wind, sky conditions, historical patterns per station.

2. **Speculative low-price entries** — Buy buckets at 1-5c that are on the path to the predicted max. Even if not the final bucket, price appreciation to 20-25c generates profit. Higher risk/reward, lottery-style.

3. **Anticipated position exit decision** — When METAR doesn't confirm an anticipated bucket, Jonah decides whether to HOLD or SELL based on: time vs peak time, temperature plateau detection (running max stagnant for 3+ METARs), and cooling trend.

4. **Polymarket GraphQL integration** — User saw dynamic data patterns in Polymarket frontend using GraphQL. Explore for real-time market data to improve decision making.
