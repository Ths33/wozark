---
name: project_backlog
description: Backlog of planned features and improvements for Wozark system
type: project
---

## Backlog

### Marty V2 — Real-time weather charts
Enrich WebSocket broadcasts (new_metar, pws_update) with full payload data from Ruth (tempC, humidity, wind, pressure, solarRadiation, etc). Marty builds time-series charts. Zero backend work needed — just expand existing broadcast calls.
**Why:** Visual context for trading decisions, spot patterns human eye catches.
**Status:** Waiting for Marty chart components. User working on Marty frontend separately.

### Wendy — Sell strategy beyond ROTATE
Currently SELL triggers via ROTATE, AI DOWNGRADE, or manual. No take-profit, no pre-resolution sell. Consider: sell at 95c+ to free capital.
**Why:** Capital efficiency — money locked in resolved positions can't be redeployed.
**Status:** Needs design discussion.

### Jonah — Prove accuracy before reconnecting to trading
Jonah in learning mode. Predictions stored in DB, accuracy tracked. Must hit >70% over 5 days before getting trade authority back.
**Why:** Flip-flopping predictions caused real losses. METAR alone works fine.
**Status:** Learning mode active. Tracking accuracy.

### Done (2026-03-25)
- ~~Jonah — Learning mode~~ → Disconnected from trading, predictions stored in DB, accuracy metrics in /health
- ~~Wendy — PWS tightened~~ → Score >= 0.70, only in 20min window before expected METAR
- ~~Wendy — Running max persistence~~ → Restores from DB on restart, no more duplicate BUYs
- ~~Wendy — Monitor duplicate detection~~ → Fixed: groups by station:tokenId. Terminal error handling.
- ~~Wendy — Monitor duplicate detection~~ → Fixed: groups by station:tokenId, not station alone. Terminal error handling for balance/allowance.
- ~~Jonah — Celsius bucket format~~ → Fixed: °C stations now get single-value predictions (7°C), not ranges (7-8°C)
- ~~Wendy — Jonah /prediction endpoint~~ → Implemented with DOWNGRADE + UPGRADE handlers
- ~~Jonah — Deploy~~ → Deployed with 4-phase architecture
- ~~Jonah — Open-Meteo forecast~~ → Integrated into dawn + briefing prompts
- ~~Marty — Insights page~~ → Redesigned with phase badges, staleness, refresh buttons
- ~~Marty — Status page~~ → Health monitoring for all services
