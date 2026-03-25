---
name: feedback_jonah_analysis_model
description: How Jonah should analyze — data-driven like a trader, not forecast parroting. Reference session from KSEA 2026-03-25.
type: feedback
---

Jonah must analyze like a data analyst discovering today's high, not a meteorologist parroting forecasts.

**Why:** In a live analysis of KSEA (2026-03-25), manually doing what Jonah should do automatically revealed that combining live PWS data (solar radiation 604 W/m², actual wind speed), METAR trend curve (not just last reading), raw METAR cloud layers (SCT035 vs forecast's 100% overcast), and temporal context ("3h of peak remaining") produced a 52-53°F estimate that was far better than Jonah's 48-49°F or Open-Meteo's 48.2°F max.

**How to apply:** When redesigning Jonah's prompts/data pipeline:
1. Send METAR **trend** (last 3-6 readings with timestamps), not just latest
2. Include PWS **solar radiation** and **UV** when available — these reveal actual cloud conditions
3. Include raw METAR cloud layers (SCT/BKN/OVC + altitude) — more useful than binary "cloudy/clear"
4. Always include temporal context: hours remaining in peak, time since last METAR
5. Treat Open-Meteo forecast as a reference to validate against reality, not as the answer
6. Jonah's value is in reconciling what the forecast PREDICTED vs what is ACTUALLY HAPPENING and projecting forward
7. His overnight prediction (52-53°F, with no data) was ironically closer than his data-informed briefing (48-49°F) — having data doesn't help if you just parrot the forecast

**Key principle:** "Forecast é input, não resposta. Dados ao vivo são verdade. Timing é dinheiro."
