---
name: project_backlog
description: Backlog of planned features and improvements for Wozark system, organized by priority
type: project
---

## Backlog

### P2 — Timing e Sell Strategy (Wendy) [Next]

**7. Time-based exit**
- `monitor.service.ts`: se posição com yesPrice < 15c e faltam <2h para resolução → SELL ao mercado
**Why:** Recuperar 10-15c/share é melhor que resolver a $0.

### P3 — Jonah Intelligence [Next]

**8. PWS features no LightGBM**
- Acumular 30+ dias de dados PWS, então retreinar LightGBM com features: pws_gap, pws_solar_peak, pws_uv, pws_trend
- Precisa ~30 dias de dados acumulados (começou 2026-03-28)
**Why:** PWS tem dados valiosos (solar, UV, gap vs METAR) que o LightGBM ignora. Target: abril 2026.

**9. Polymarket price-weighted bucket selection**
- Jonah consulta preços dos buckets via Gamma API como input adicional para GPT-5
**Why:** Preços Polymarket são crowd consensus — ensemble gratuito.

### Critérios de Sucesso
- [ ] Win rate >= 50% sustentado por 5+ dias
- [ ] Jonah accuracy >= 60% (primary + secondary bucket)
- [ ] P&L semanal positivo consistente

### Done (2026-04-03) — Codex Sprint

**Jonah:**
- ~~Pre-METAR predictions~~ → 55min cycle fires ~5min before next METAR, records crossing + non-crossing evaluations
- ~~Intraday drift learning~~ → RAG learns drift patterns after early correct calls (drift_count, recovery, confidence/PWS jumps)
- ~~Learning metrics endpoints~~ → GET /learning/metrics + /learning/debug + POST /admin/learning
- ~~GPT bucket canonicalization~~ → Two-stage normalization to valid even-odd market buckets
- ~~Manual run isolation~~ → phase=manual doesn't affect scheduled state, accepts observed temps
- ~~Heartbeat system~~ → healthy/waiting/stale/missing status per station
- ~~Per-source error tracking~~ → LightGBM, Chronos, Open-Meteo, RAG accuracy in learning_outcomes
- ~~Non-crossing pre-METAR records~~ → Hold decisions recorded for learning evaluation

**Wendy:**
- ~~Jonah-gated METAR execution~~ → observe-only mode, waits for Jonah pre_metar confirmation (metarTradingEnabled)
- ~~Learning proxies~~ → /learning/metrics + /learning/run + /learning/debug proxied for Marty
- ~~Observed temps to manual runs~~ → Wendy sends running_max_c + current_temp_c to Jonah
- ~~Bucket label normalization~~ → canonicalizePredictionBucket() snaps to even-odd°F
- ~~Phase normalization~~ → dawn→briefing, update→peak_update
- ~~Board weather summaries~~ → Feed state (live/fallback/missing) with age, wind, humidity
- ~~95% confidence early trades~~ → High confidence triggers bypass early trading window

**Marty:**
- ~~Learning monitor~~ → /learning page with accuracy trends, source errors, RAG size
- ~~Intraday learning audit~~ → Grouped by station, shows per-update verdict
- ~~Admin learning controls~~ → Manual trigger + debug date + resolution audit
- ~~Jonah heartbeat display~~ → Status, cadence, next cycle countdown
- ~~Feed state display~~ → Live/fallback/missing badges for METAR + PWS
- ~~Local time + Brasília time~~ → Dual timezone display on station detail
- ~~Jonah-gated execution clarity~~ → Shows execution mode and confirmation state

### Done (2026-03-30)
- ~~Wendy — confirmedBuckets rotation fix~~ → Allows METAR rotation through previously confirmed buckets
- ~~Jonah — Trigger sanity check~~ → Suppresses rotation triggers with lower confidence than previous
- ~~Wendy — ROTATE SELL error logging~~ → Serializes error message properly, logs partial success
- ~~Wendy — FOK phantom fill fix~~ → Always verifies via getOrder(), never trusts matched status alone
- ~~Wendy — SELL feeRateBps fix~~ → SellService auto-fetches fee rate when not provided by caller
- ~~Jonah — COASTAL set~~ → Added KSFO + KLAX (bay/ocean-adjacent)
- ~~Jonah — LightGBM retrained~~ → 10 US stations (was 6), 18,594 samples from 5yr IEM data
- ~~Jonah — GPT-5 as decision-maker~~ → GPT-5 overrides ensemble, receives all raw data
- ~~Jonah — METAR-driven 55min cycle~~ → Predictions fire 55min after METAR
- ~~Jonah — Floor enforcement~~ → Predicted bucket can never be below observed running max

### Done (2026-03-29)
- ~~RAG backfill~~ → 3,650 vectors in Qdrant (365d × 10 stations) via Iowa Mesonet
- ~~Dockerfile scripts/~~ → Added COPY scripts/ to Jonah Dockerfile
- ~~DB cleanup~~ → Removed CYYZ/EGLC/LFPG data from both DBs

### Done (2026-03-28)
- ~~P1.3/4/5 — Jonah as trade trigger~~ → POST /trigger to Wendy
- ~~P4.11 — Marty V2~~ → Mobile-first shadcn redesign
- ~~Stations: US-only~~ → 10 stations, all °F
- ~~Wendy — CLOB API wrapper~~ → Dynamic feeRateBps/tickSize/negRisk
- ~~Wendy — PayloadCache~~ → Static payloads at startup, fresh book at trigger
- ~~Wendy — Kill switch~~ → tradingEnabled=false blocks ALL orders
