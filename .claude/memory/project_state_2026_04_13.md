---
name: Project state 2026-04-13
description: Current architecture state after Synoptic pivot and Marty source badges
type: project
originSessionId: 6fbec674-b981-4501-b7e4-315eaee889f9
---

**Synoptic pivot (completed 2026-04-13):**

- Ruth now uses Synoptic Data API as PRIMARY source (polls every 5min), tgftp as FALLBACK only
- `source: "synoptic" | "tgftp"` field added to MetarSignal — flows Ruth → Wendy → Marty
- Marty airport badge: green = synoptic live, yellow = tgftp fallback
- 1h rolling max (`max1hC`) broadcast in new_metar WS event; shows in airport meta when != current temp
- Critical alert `[SYNOPTIC_DOWN]` logged every 3 failures; `[SYNOPTIC_RECOVERED]` on restore

**Jonah state:** TRIGGER_ENABLED=False — learning-only mode, no trade triggers fired

**Trading state:** tradingEnabled=false — user plans to enable tomorrow (2026-04-14) with $10

**Synoptic timing in learning:** `synoptic_accuracy` JSONB in `learning_outcomes` tracks first_max_local_hour, readings_before_max, stability_minutes, hourly_profile per station per day

**Why:** User wants to observe data quality before enabling live trading.
**How to apply:** When trading is enabled, re-enable Jonah triggers (TRIGGER_ENABLED=True in proxy.py) and set tradingEnabled=true in DB/settings.
