---
name: project_backlog
description: Backlog of planned features and improvements for Wozark system, organized by priority
type: project
---

## Backlog

### P0 — Parar de Perder (Wendy) [Semana 1]

**1. Guards de capital e portfolio**
- Guard `isPortfolioExposureExceeded`: rejeitar trades se exposicao total > $40 (nova config `MAX_PORTFOLIO_EXPOSURE` em app_config)
- Guard `hasMaxPositionsPerStation`: max 1 posicao ativa por estacao (elimina acumulacao em buckets intermediarios)
- Reduzir `tradingMaxDailyLoss` default de 50 → 15
- Subir piso de preco de entrada de 10c → 20c (entries <20c tem 12% win rate)
**Why:** Bot deployou $1,204 em 2 dias com 29% win rate. Sem controle de portfolio, cada estacao opera isolada.
**How to apply:** Todos sao guards novos em `guards.ts` + config em `config.ts`. Nao alteram logica existente.

**2. Desabilitar PWS como trigger de trade**
- `anticipation.service.ts`: remover logica de BUY, manter calculo + broadcast + DB save
- `signal.service.ts`: remover `anticipatedPosition` do StationState e validacao PWS-vs-METAR
- Adicionar config flag `PWS_TRADING_ENABLED` (default: false) para reabilitar no futuro
**Why:** PWS anticipation foi a maior fonte de perdas — compra buckets que a temperatura "passa por cima" sem confirmar como maximo.
**How to apply:** Editar anticipation.service.ts e signal.service.ts. PWS continua alimentando dados para Jonah.

### P1 — Jonah como Filtro de Trading (Jonah + Wendy) [Semana 2]

**3. Target bucket no payload de Jonah**
- `proxy.py`: adicionar `action_type` (HOLD/TARGET/AVOID) e `secondary_bucket` ao payload
- `predictor.py`: quando confidence >= 0.70, marcar como TARGET com primary + secondary bucket
**Why:** Wendy precisa saber se deve agir. Hoje Jonah so envia bucket/confidence sem indicacao de acao.

**4. Wendy armazena e consulta target de Jonah**
- Novo arquivo `src/shared/jonah-state.ts`: Map<station, { targetBucket, secondaryBucket, confidence, phase, updatedAt }>
- `prediction.route.ts`: atualiza mapa quando recebe TARGET
- Guard `isAlignedWithJonah` em `guards.ts`:
  - METAR bucket == primary ou secondary → allowed
  - METAR bucket != target → blocked (waypoint)
  - Jonah offline → fallback conservador: so compra se preco >= 40c
- Integrar guard no `signal.service.ts` via `runGuards()`
**Why:** Core da mudanca — em vez de comprar cada threshold crossing, so compra alinhado com previsao de pico.

**5. Graduar Jonah de learning mode**
- `predictor.py`: ativar `push_upgrade()` / `push_downgrade()` (remover comentarios "learning mode")
- DOWNGRADE com confidence >= 0.80 → trigger de SELL na Wendy (config `JONAH_SELL_ENABLED`, default: false)
**Why:** Jonah precisa enviar sinais ativos para Wendy usar como filtro. SELL via DOWNGRADE e a unica exit strategy alem de resolucao.
**Prerequisite:** Jonah accuracy >= 60% por 5+ dias em learning mode.

### P2 — Timing e Sell Strategy (Wendy) [Semana 3]

**6. Confirmation window para METAR**
- `signal.service.ts`: primeiro METAR no bucket alvo → `pendingConfirmation`. Segundo METAR confirmando → compra. Se cair → cancela (spike).
- Excecao: METAR 2+ buckets acima do threshold → skip confirmation
**Why:** Spikes de 1 METAR que cruzam e voltam sao fonte de perdas. Dados: entries com preco alto (confirmados) tem 50% win rate.

**7. Janela temporal restrita**
- `guards.ts`: trading so apos `analysisStart` local (10-11am) ao inves de 7am
**Why:** Trades matinais (7-10am) tem win rate baixo — temperatura longe do pico, muita variacao.

**8. Time-based exit**
- `monitor.service.ts`: se posicao com yesPrice < 15c e faltam <2h para resolucao → SELL ao mercado
**Why:** Recuperar 10-15c/share e melhor que resolver a $0. Em volume, soma.

### P3 — Melhoria de Prompts Jonah [Semana 3-4]

**9. Enriquecer prompts com dados de mercado**
- `predictor.py`: buscar precos dos buckets via Wendy API e incluir no prompt
**Why:** Mercado e ensemble de previsores. Se mercado diz 56-57 e mais provavel (45c), e sinal forte.

**10. Contexto vento/solar aprimorado**
- `predictor.py`: incluir licao KSEA no prompt — "strong solar + strong wind = temp cap"
- Incluir wind speed/direction do METAR raw no contexto
**Why:** Jonah superestimou KSEA por ignorar vento. Buffer ja tem dados.

### P4 — Marty V2 e Dashboards

**11. Real-time weather charts**
Enrich WebSocket broadcasts (new_metar, pws_update) with full payload data from Ruth. Marty builds time-series charts.
**Why:** Visual context for trading decisions, spot patterns human eye catches.
**Status:** Waiting for Marty chart components.

### Criterios de Sucesso do Plano de Lucratividade
- [ ] Win rate >= 50% sustentado por 5+ dias
- [ ] Nenhuma posicao em bucket intermediario (waypoint)
- [ ] Capital deployado total < $50 a qualquer momento
- [ ] Max 1 posicao ativa por estacao
- [ ] Jonah accuracy >= 60% (primary + secondary bucket)
- [ ] P&L semanal positivo consistente

### Done (2026-03-25)
- ~~Jonah — Learning mode~~ → Disconnected from trading, predictions stored in DB, accuracy metrics in /health
- ~~Wendy — PWS tightened~~ → Score >= 0.70, max 1 bucket jump, only in 20min window before expected METAR
- ~~Wendy — Running max persistence~~ → Restores from DB on restart, no more duplicate BUYs
- ~~Wendy — Monitor duplicate detection~~ → Fixed: groups by station:tokenId. Terminal error handling.
- ~~Jonah — Celsius bucket format~~ → Fixed: C stations get single-value predictions (7C), not ranges (7-8C)
- ~~Wendy — Jonah /prediction endpoint~~ → Implemented with DOWNGRADE + UPGRADE handlers
- ~~Jonah — Deploy~~ → Deployed with 4-phase architecture
- ~~Jonah — Open-Meteo forecast~~ → Integrated into dawn + briefing prompts
- ~~Marty — Insights page~~ → Redesigned with phase badges, staleness, refresh buttons
- ~~Marty — Status page~~ → Health monitoring for all services

### Done (2026-03-28)
- ~~P1.3/4/5 — Jonah as trade trigger~~ → Jonah fires POST /trigger to Wendy when MEDIUM/STRONG timing (confidence >= 70%). Supports BUY and ROTATE.
- ~~P4.11 — Marty V2~~ → Complete redesign: mobile-first shadcn, station detail (METAR + PWS + anticipation), per-station logs, breadcrumb nav, auto-refresh (30s/60s), /data/:station raw view. Removed Jonah page.
- ~~Stations: US-only~~ → 10 stations (removed CYYZ/EGLC/LFPG/KBKF, added KLAX/KSFO/KAUS/KHOU). All °F.
- ~~PWS IDs fixed~~ → KLGA, KMIA, KATL, KORD, KSEA updated to correct PWS station IDs.
- ~~Wendy — CLOB API wrapper~~ → Direct /price, /midpoint, /spread, /fee-rate, /tick-size. Dynamic feeRateBps/tickSize/negRisk.
- ~~Wendy — Spread guard~~ → > 6c = skip trade.
- ~~Wendy — PayloadCache~~ → Static payloads at startup, fresh book at trigger time.
- ~~Wendy — Kill switch~~ → tradingEnabled=false blocks ALL orders in BuyService + SellService. Monitor respects it.
- ~~Wendy — FOK fast-path~~ → Matched = instant verification, no polling.
- ~~Wendy — Threshold upward only~~ → Detection only fires on temperature increases, not drops.
- ~~Wendy — External trades~~ → Logged to DB with signalType=EXTERNAL.
- ~~Wendy — /data/:station~~ → Meteorological data endpoint (JWT protected).
- ~~Wendy — /system/status~~ → Includes Jonah DB health.
- ~~Ruth — Dynamic stations~~ → Fetches station list from Wendy, no hardcoded list.
- ~~Ruth — US altimeter + VRB wind~~ → Parses A-group pressure and VRB wind direction.
- ~~Jonah — Bug fixes~~ → metarRaw field, numpy float64 serialization, learning.py valid_utc, prediction payload wrapping, range detection uses Polymarket even-odd buckets.
- ~~Jonah — GPT-5 rapid mode~~ → Enabled in rapid mode near peak.
