---
name: project_jonah_v5
description: Jonah V5 — 4-source ensemble + GPT-5 independent predictor, range detection, timing signals, /trigger execution
type: project
---

Jonah V5 refactored on 2026-03-27. Major architecture change from V4.

**V4 problem:** Claude-as-judge had 100% JSON parsing failure rate (max_tokens=150 truncated responses). All predictions were failing silently.

**V5 Architecture:** 4-source mathematical ensemble + GPT-5 independent predictor:
1. LightGBM quantile regression (5yr NOAA/IEM, 18K samples across 10 stations, w=0.25)
2. Chronos-Bolt-Small (time-series, thread-safe, w=0.20)
3. Open-Meteo NWP forecast (w=0.15)
4. RAG similar days from Qdrant (5yr backfill, ~18K data points, w=0.25)

**GPT-5** is an independent pre-METAR predictor (w=0.15), not part of the ensemble judge. Uses `response_format=json_object` for guaranteed valid JSON. Better than Claude for meteorological reasoning.

**Floor filter:** Predictions with range_prob below floor are filtered out before trigger.

**Key change:** Each source outputs `{temp_int: probability}` → weighted average → range detection → timing signal. No JSON parsing of free-form text.

**Output format:**
```
range="58-59", range_prob=0.77, confidence=0.74, timing="MEDIUM"
```

**Timing thresholds (updated 2026-03-29):**
- WAIT: <30% → don't enter
- SMALL: 30-40% → small position
- MEDIUM: 40-55% → medium position
- STRONG: 55%+ → full position

**DB fix:** init_db() now auto-creates jonah_prod database if missing.

**RAG status (2026-03-29):**
- NOT real-time: vectors only added 1x/day (learning.py). Ensemble queries RAG but doesn't feed it.
- Backfill complete: ~18K vectors in Qdrant (5yr × 10 stations via IEM).
- `scripts/noaa_backfill.py` uses Iowa Mesonet (IEM), includes humidity/wind/dewpoint, --dry-run/--stations flags.
- Formatter handles backfill points (was_correct=None → "historical only" label).
- Dockerfile now copies scripts/ dir into container.

**LightGBM:** 18K training samples across 10 stations from IEM backfill.

**Chronos:** Thread-safe implementation (was causing issues before fix).

**Status:** Deployed (V5). OPENAI_API_KEY configured. Trigger pipeline active (timing thresholds → POST /trigger to Wendy).
