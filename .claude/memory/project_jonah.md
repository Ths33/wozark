---
name: Project Jonah - AI Weather Analyst
description: Jonah in LEARNING MODE since 2026-03-25 — disconnected from trading, storing predictions for accuracy tracking. Must prove >70% accuracy before reconnecting.
type: project
---

Jonah is running in **learning mode** — predictions are stored and tracked but do NOT trigger trades.

**Why:** Jonah was reactive (flip-flopping predictions), causing losses. METAR + PWS alone work fine for trading. Jonah must prove consistent accuracy before being trusted with money again.

**Repo:** git@github.com:Ths33/jonah.git
**Stack:** Python 3.12, FastAPI, Anthropic SDK (Sonnet + Haiku), Qdrant, Open-Meteo, APScheduler
**Cost:** ~$0.50/day (~$15/month)

**Current state (2026-03-25):**
- DOWNGRADE/UPGRADE signals → logged only, no trade execution
- Every prediction stored in `predictions` table (station, bucket, confidence, phase, reasoning, forecast_max, metar_at_prediction)
- Learning loop (02:00 UTC) fills actual_bucket, was_correct, error_value for each prediction
- Accuracy metrics in /health endpoint per station
- Self-knowledge in prompts: "Your track record: X% accuracy, avg error Y°"
- Predictions still broadcast to Marty (visibility only)

**Reconnection criteria:** accuracy > 70% over 5+ consecutive days (to be validated)

**Key issues that led to learning mode:**
- Overnight predicted "32-33°F Late January NYC" in March (hallucinated month, no data)
- Peak updates chased METAR instead of predicting daily high (7°C → 6°C → 7°C in 30min)
- Briefing ran 5x in 3h instead of once
- °C stations got ranges instead of single values (fixed)
