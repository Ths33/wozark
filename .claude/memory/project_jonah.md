---
name: Project Jonah - AI Weather Analyst
description: Planned 4th service for AI-powered daily max temperature prediction, enabling early entry on correct bucket before market prices it in
type: project
---

Jonah is the planned 4th service in the Wozark architecture — an AI analyst that predicts daily maximum temperatures using weather data, historical patterns, and RAG.

**Why:** Current PWS anticipation predicts the "next bucket" (short-term), not the daily max. This leads to buying waypoint buckets (e.g., 80-81°F at 11am Miami) instead of the likely max (83-84°F). AI analysis of conditions (humidity, wind, sky, time of day, peak time, historical patterns) can predict the actual max and enter early at low prices.

**How to apply:** Jonah will be a separate project (like Ruth/Wendy/Marty) with its own repo and deployment. Architecture:

```
Ruth (Sensor) → Wendy (Brain) → Marty (Dashboard)
                    ↑
                Jonah (Analyst)
```

Two signal sources for Wendy:
1. **Jonah** — strategic entry (AI predicts daily max → buy that bucket early at low price)
2. **METAR** — tactical confirmation (reposition / increase position when temperature confirmed)

Jonah will use RAG with historical data, seasonal patterns, station-specific accuracy tracking. Stack TBD.

**Financial context:** Project has consumed ~$600 (infra + AI tokens + trading losses) as of 2026-03-24. Goal is to reach break-even before scaling further. Today's wins: Paris +290%, London +528% on correct bucket entries.
