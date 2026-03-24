---
name: Trading Lessons from 2026-03-24
description: First full day of V5 trading — key observations about PWS bias, buy-sell loops, and harvest conflicts
type: project
---

Lessons from first production trading day (2026-03-24):

**Wins:**
- Paris +290%, London +528% — correct bucket entries via PWS anticipation
- PWS anticipation works well when entry is near peak time (Paris ~12:30 local)

**Losses/Issues:**
- PWS has systematic 2-4°F upward bias vs METAR — predicts 72°F when real max is 68°F
- Buy-sell loop: PWS buys → METAR doesn't confirm → auto-sell → PWS rebuys (fixed: disabled PWS_EXIT)
- Harvest bought NO against our own YES positions (Atlanta 68-69°F)
- Bot tried to SELL positions already closed manually on Polymarket ("not enough balance")
- Multiple conflicting trades on same station within minutes (Chicago, NY, Atlanta)

**Key insight:** PWS anticipation buys the "next bucket" but Polymarket pays on daily HIGH. At 11am Miami buying 80-81°F when market says 82-83°F is burning money — 80-81 is a waypoint, not the max. This is exactly what Jonah should solve.

**How to apply:** Before adding trading logic, verify it won't create loops or act against existing positions. Portfolio sync must happen before trade decisions, not just every 3min. Harvest must exclude buckets where we have YES positions.
