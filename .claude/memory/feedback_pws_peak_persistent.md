---
name: feedback_pws_peak_persistent
description: PWS peak temp must be persisted (daily, per station:pwsId) not browser-session. Feed to Jonah for analysis.
type: feedback
---

PWS peak temperature per day per station must be stored server-side, not accumulated in browser memory.

**Why:** Browser-session peaks reset on page reload and are useless for analysis. The daily peak of each PWS vs METAR peak shows systematic bias and solar heating patterns that Jonah needs for better predictions.

**How to apply:** Store pws_peak_f in Jonah's buffer (resets on day change). Expose via Wendy /data/:station and WS broadcast. Marty reads from server, not local accumulation. Jonah uses PWS peaks in GPT-5 prompt context for better peak temperature reasoning.
