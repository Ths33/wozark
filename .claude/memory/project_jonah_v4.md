---
name: project_jonah_v5
description: Jonah V5 mathematical ensemble — GPT-5 + 4 sources with range detection and timing signals, replaces fragile Claude-as-judge
type: project
---

Jonah V5 refactored on 2026-03-27. Major architecture change from V4.

**V4 problem:** Claude-as-judge had 100% JSON parsing failure rate (max_tokens=150 truncated responses). All predictions were failing silently.

**V5 Architecture:** 5-source mathematical ensemble — no LLM judge:
1. LightGBM quantile regression (5yr NOAA/IEM, w=0.25)
2. Chronos-Bolt-Small (time-series, w=0.20)
3. Open-Meteo NWP forecast (w=0.15)
4. RAG similar days from Qdrant (w=0.25)
5. GPT-5 meteorological reasoning (w=0.15, json_object response format)

**Key change:** Each source outputs `{temp_int: probability}` → weighted average → range detection → timing signal (WAIT/SMALL/MEDIUM/STRONG). No JSON parsing of free-form text. GPT-5 is just another source, not the decision maker.

**Why GPT-5 over Claude:** Claude Sonnet/Haiku are coding models. GPT-5 is better for meteorological reasoning/analysis tasks. Also uses `response_format=json_object` for guaranteed valid JSON.

**Output format:**
```
range="58-59", range_prob=0.77, confidence=0.74, timing="MEDIUM"
```

**Timing thresholds:**
- WAIT: <60% → don't enter
- SMALL: 60-70% → small position
- MEDIUM: 70-80% → medium position
- STRONG: 80%+ → full position

**DB fix:** init_db() now auto-creates jonah_prod database if missing.

**Status:** Code complete, needs deploy + OPENAI_API_KEY in CapRover.
