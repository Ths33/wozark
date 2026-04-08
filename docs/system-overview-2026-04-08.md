# Wozark V5 — System Overview (2026-04-08)

Este documento reflete o estado REAL do sistema hoje — extraído do código, não do planejamento.

---

## Arquitetura

```
Ruth (Rust)          → sensor: METAR + PWS
  ↓ POST /signal
Wendy (TypeScript)   → cérebro: decisões + execução CLOB
  ↓ WebSocket
Marty (React)        → dashboard em tempo real

Jonah (Python)       → IA: ensemble + GPT-5
  ↓ POST /trigger + /prediction
Wendy               → executa trade
```

---

## 1. Ruth — Sensor (Rust/Axum)

### METAR Polling

- URL: `https://tgftp.nws.noaa.gov/data/observations/metar/stations/{ICAO}.TXT`
- Intervalo **adaptativo**: `3s` dentro da janela ±5min do METAR esperado, `60s` fora
- Aprende o minuto do último METAR (ex: `:53`) e cria janela `[48, 58]`
- Dedup por chave `ICAO:DDHHMMz` — HashSet resetada a cada hora UTC
- METAR = **ground truth**. Qualquer SPECI no arquivo é capturado automaticamente

### PWS Polling

- Intervalo fixo: `300s` (5 min)
- API: Weather Underground v2 (`/pws/observations/current`)
- 3 PWS por aeroporto, em paralelo via tokio::spawn

### Payload enviado ao Wendy (METAR)

```json
{
  "type": "METAR",
  "station": "KSEA",
  "tempC": 10.5,
  "tempF": 50.9,
  "dewpointC": 8.2,
  "humidityPct": 85,
  "windDeg": 180,
  "windKt": 12,
  "gustKt": 18,
  "visibilityM": 10000,
  "cloudLayers": [{ "cover": "BKN", "altitude": 1500 }],
  "pressureHpa": 1013.2,
  "metarRaw": "KSEA 291856Z ...",
  "metarTime": "2026-04-07T18:56:00Z",
  "capturedAt": "2026-04-07T18:56:00.123Z",
  "traceId": "ruth-metar-ksea-20260407-185600123"
}
```

### Resiliência

- **Circuit breaker:** 10 falhas consecutivas → 30s backoff
- **Retry buffer:** max 20 items, TTL 30s — drena ao reconectar com Wendy
- Jonah recebe cópia fire-and-forget (não bloqueia o path principal)

---

## 2. Wendy — Brain (TypeScript/Fastify 5)

### Estado por estação (em memória)

```typescript
{
  runningMaxC: number          // máximo do dia — NUNCA desce
  lastTempC: number            // último METAR recebido
  lastBucket: string | null    // último bucket operado
  lastTokenId: string | null   // tokenId do bucket atual
  confirmedBuckets: Set        // buckets já comprados hoje
  lastDate: string | null      // YYYY-MM-DD local da estação
  lastMetarAt: Date | null
  anticipatedPosition: {...}   // posição PWS esperando confirmação METAR
  metarCadence: number | null  // EMA dos gaps entre METARs (segundos) — α=0.3, ignora gaps <120s ou >7200s
}
```

`metarCadence` é calculado a cada METAR recebido e exposto via `getMetarCadence()` (retorna 3600 como default). **O getter nunca é chamado em nenhum lugar do código.** Candidato a remoção ou uso no heartbeat de estação (ex: detectar METAR atrasado quando `now - lastMetarAt > metarCadence * 1.5`).

```typescript

```

### getBucket — Algoritmo de Bucket (temperature.ts)

Converte temperatura °C → bucket de mercado (par even-odd em °F):

```typescript
cToF(c) = c * 9/5 + 32

getFBucket(tempC):
  f   = Math.round(cToF(tempC))       // ARREDONDAMENTO, não floor
  low = f % 2 === 0 ? f : f - 1       // snapa para o par mais próximo abaixo
  return { low, high: low + 1 }       // ex: 70-71°F, 72-73°F

// Exemplos:
// 21.1°C → 70.0°F → f=70 (par) → bucket 70-71°F
// 21.7°C → 71.1°F → f=71 (ímpar) → low=70 → bucket 70-71°F
// 22.2°C → 72.0°F → f=72 (par) → bucket 72-73°F
// 21.4°C → 70.5°F → f=71 (Math.round) → low=70 → bucket 70-71°F
```

**Ponto crítico:** usa `Math.round`, não `Math.floor`. Isso significa que 21.4°C (70.5°F) vai para o bucket 70-71°F, não 68-69°F. A fronteira efetiva entre buckets está em `.5°F`, não em valores inteiros.

### Fluxo METAR (signal.service.ts)

1. Salvar no DB (fire-and-forget)
2. Broadcast `new_metar` → Marty
3. **Day change detection** → reset runningMaxC, lastBucket, confirmedBuckets
4. Atualizar `runningMaxC = Math.max(runningMaxC, tempC)` (monotônico)
5. Calcular bucket via `getBucket(runningMaxC, station)` — usa o **máximo**, não temp atual
6. **Threshold crossing** (apenas upward — se bucket > lastBucket):
   - Primeiro METAR do dia → baseline, sem trade
   - Jonah já comprou este bucket → SKIP
   - Jonah comprou bucket diferente + METAR > Jonah bucket → ROTATE UP
   - Sem posição Jonah → **BUY confirmativo**
7. **Dead bucket guard (2026-04-08):** se `yesPrice < $0.05` → skip com reason `dead_bucket_metar` (mercado descartou o bucket antes do METAR confirmar)
8. Rodar guards antes de qualquer trade
9. **Cascade guard (2026-04-08):** no path de ROTATE, conta posições abertas da estação. Se > 1 → skip com reason `cascade_guard` (posição órfã de SELL falho anterior)
10. Executar BUY ou ROTATE
11. Broadcast `trade_executed` → Marty

### Fluxo PWS (anticipation.service.ts)

PWS é **data-only**. Não gera trades autônomos.

- Alimenta buffer do Jonah via `/signal {type: "PWS"}`
- Jonah usa os dados para ensemble e pre-METAR prediction

### ROTATE (rotate.service.ts)

```
1. BUY novo bucket (await — deve ter sucesso)
2. Se BUY falha → return (posição fica no bucket antigo)
3. Se BUY sucede:
   a. Verificar bid do bucket antigo
   b. Se bid < $0.03 → skip SELL (bucket morto, sem compradores)
   c. Caso contrário → SELL antigo
4. Broadcast resultado
```

### Guards (guards.ts) — thresholds reais

| Guard                    | Condição de bloqueio                         |
| ------------------------ | -------------------------------------------- |
| `outside_trading_window` | hora local < peakRange[0] ou >= peakRange[1] |
| `market_resolved`        | yesPrice >= $1.00                            |
| `price_out_of_range`     | yesPrice < $0.05 ou >= $0.75                 |
| `border_zone`            | yesPrice entre $0.45 e $0.55                 |
| `no_book_liquidity`      | bids.length === 0                            |
| `spread_too_wide`        | spread > $0.06                               |
| `daily_loss_exceeded`    | dailySpend >= maxDailyLoss                   |
| `trade_locked`           | station:bucket já em execução                |

### Fluxo /trigger (Jonah → Wendy)

1. Validar station enabled, trading enabled
2. Fetch tokenId da PayloadCache
3. Edge bucket fallback: se bucket exato não existe → tenta "X°F or higher"
4. Rodar guards
5. **Max 1 bucket jump**: Jonah pode trigger no máximo 1 bucket (2°F) acima do METAR atual
6. Downward ROTATE bloqueado
7. Sanity check: não rotacionar para bucket com confidence < trigger anterior
8. BUY ou ROTATE
9. Salvar resultado em DB (`jonah_triggers`)

### SELL_STRANDED (signal.service.ts)

Quando `price_out_of_range` bloqueia uma ROTATE:

1. Verificar bid do bucket antigo
2. Se bid < $0.03 → log "worthless, abandoning" — não tenta vender
3. Se bid >= $0.03 → tentar SELL do bucket perdedor

### PayloadCache (payload-cache.ts)

- Carga na startup + reload a cada **30 minutos**
- Fresh Maps por reload (evita tokenIds de dia anterior)
- `fire(station, bucket)`: merge payload estático + fresh book snapshot

### Monitor (monitor.service.ts) — tick a cada 3 min

1. Refresh price snapshots
2. Detectar posições duplicadas (agrupa por `station:tokenId`)
3. Manter maior posição, agendar SELL retry para o resto
4. SELL retries: max 3 tentativas, terminal errors (allowance/balance) drop imediato

---

## 3. Jonah — Analyst (Python/FastAPI)

### Ensemble (4 fontes)

| Fonte      | Peso     | Descrição                                       |
| ---------- | -------- | ----------------------------------------------- |
| LightGBM   | **0.20** | 7 modelos quantile, 18.594 samples IEM (5 anos) |
| Chronos    | 0.25     | Amazon time-series, forecast 48h                |
| Open-Meteo | **0.30** | NWP grid forecast (API gratuita)                |
| RAG        | 0.25     | Qdrant: dias similares, 18.250 pontos           |

**Rebalanceamento 2026-04-08:** Open-Meteo elevado de 0.20 → 0.30 (viés -1 a +2°F, mais preciso empiricamente). LightGBM reduzido de 0.30 → 0.20 (sobre-estima sistematicamente +3 a +10°F).

**Cada fonte retorna:** `{temp: int → prob: float}` — distribuição de probabilidade

**Combinação:**

```python
combined[temp] += prob * weight  # soma ponderada
combined = renormalize(combined)
```

**Floor enforcement (corrigido 2026-04-08):**

```python
bucket_width = 2  # para °F
removed = {k: v for k, v in combined.items() if k + bucket_width <= observed_max}
# bucket k só é removido se TODA a faixa [k, k+2) já foi ultrapassada
# ANTES (bug): int(observed_max) removia o bucket atual
```

### GPT-5 — Final Decision-Maker

**Recebe:**

- METAR history (últimas 24h)
- PWS readings (últimos 60 min)
- Solar radiation, UV, slopes (1h, 15min)
- Saídas do ensemble (com confidence de cada fonte)
- Running max observado
- **Preços do Polymarket** (crowd consensus)
- NWS grid forecasts + AFD products

**Config:**

- Modelo: `gpt-5`
- `max_completion_tokens`: 16384
- `response_format`: json_object
- Timeout: 60s
- GPT **override** ensemble — ensemble é fallback se GPT falhar
- **Divergence cap (2026-04-08):** se GPT-5 divergir > 4°F (2 buckets) do ensemble → descarta GPT-5, usa ensemble. Evita casos onde prior da cidade destrói sinal correto em dias atípicos

**Output:**

```json
{
  "bucket": "64-65°F",
  "timing": "STRONG",
  "confidence": 0.82,
  "reasoning": "..."
}
```

### Timing Signals

| Signal        | Threshold  | Comportamento                  |
| ------------- | ---------- | ------------------------------ |
| STRONG        | >= 55%     | Dispara /trigger               |
| MEDIUM        | >= 40%     | Dispara /trigger               |
| SMALL         | >= 30%     | Advisory apenas (sem trigger)  |
| WAIT          | < 30%      | Sem ação                       |
| **Pre-METAR** | **>= 70%** | Threshold maior (anticipatory) |

### Ciclo :48 (APScheduler cron)

- Roda exatamente às :48 de cada hora UTC
- Para cada estação dentro do `peak_range` local:
  - Sem dawn prediction hoje → `run_dawn()` (primeira predição)
  - Status `active` → `_pre_metar_prediction()` (update antes do próximo METAR)
- Jonah escolheu :48 pois METARs típicos chegam ~:53 → 5 min de antecedência

### Pre-METAR Prediction

Executada no ciclo :48 para estações ativas:

```
gap = median(PWS_últimos_10min) - T_metar_last
slope_15m = regressão linear dos PWS últimos 15min (°/hora)
T_estimado = T_metar + gap × 0.7 + slope_15m × (5min/60)
bucket_estimado = getBucket(T_estimado)
```

- Requer **confidence >= 70%** para disparar /trigger
- Grava avaliação (crossing e non-crossing) para learning

### RAG (Retrieval-Augmented Generation)

**Qdrant** — 18.250 pontos (5 anos, 10 estações)

Cada ponto armazena:

```
{date, station, observed_max_c, temp_probs, sources_accuracy,
 conditions: {clouds, wind, solar, humidity}, embedding}
```

- **Query:** busca dias similares baseado em condições atuais (embedding similarity)
- **Learning:** nightly às 06:00 UTC — compara predictions vs actuals, armazena outcomes em Qdrant + `learning_outcomes`
- **Backfill automático** na startup se Qdrant vazio

### LightGBM — Retraining

**`_retrain_lgbm()` em `learning.py` é um stub:**

```python
async def _retrain_lgbm():
    logger.info("LightGBM retrain: skipped (using pre-trained models)")
```

- Modelos foram treinados manualmente em **2026-03-30** (18.594 amostras, 5 anos IEM, 10 estações)
- O loop de learning nightly **NÃO retreina** o LightGBM — apenas armazena outcomes no Qdrant
- Os pesos do ensemble (`WEIGHT_LGBM/CHRONOS/OPENMETEO/RAG`) são **env vars fixas**, nunca ajustadas automaticamente
- Consequência: LightGBM não aprende com erros recentes. Somente o RAG (Qdrant) acumula memória operacional

### Quando Jonah dispara /trigger para Wendy

- Timing MEDIUM (>= 40%) ou STRONG (>= 55%) → BUY
- Pre-METAR: confidence >= 70%
- Downward ROTATE: bloqueado (daily max é monotônico)
- **Condição de SELL:** confidence cai abaixo de 20% → POST /trigger com signal="SELL"
- **Market converged guard (2026-04-08):** se melhor bucket >= $0.90 → skip GPT-5 + suprime trigger. Predição ensemble ainda é salva sem trigger. Log: `"market_converged: best bucket {bucket} at $X.XX"`

---

## 4. Marty — Dashboard (React 19/Next.js)

### Páginas

| Página            | Conteúdo                                                    |
| ----------------- | ----------------------------------------------------------- |
| `/`               | Station board: 10 cards com temp live, posições, feed state |
| `/station/[icao]` | Detail: buckets, timeline, posição atual                    |
| `/positions`      | Todas as posições: open, losses, redeem                     |
| `/logs`           | Logs filtráveis + TraceTimeline + filtro "Today"            |
| `/settings`       | Config do bot (tradingEnabled, maxDailyLoss, stations)      |
| `/status`         | Health: Ruth, Wendy, Jonah                                  |
| `/learning`       | Accuracy stats por fonte, per-station                       |

### WebSocket Events Recebidos

| Event             | O que faz                                                            |
| ----------------- | -------------------------------------------------------------------- |
| `new_metar`       | Atualiza temp live, append history                                   |
| `pws_update`      | Atualiza PWS, peak temps diário                                      |
| `trade_executed`  | Log + highlight da estação                                           |
| `trade_skipped`   | Log motivo                                                           |
| `ai_prediction`   | Exibe no painel GPT-5 reasoning                                      |
| `position_update` | Refresh posições                                                     |
| `error`           | Toast — se contiver "token/invalid/unauthorized" → logout automático |

---

## 5. Fluxo Completo — Trade Ciclo

```
[Ruth]
Poll NOAA (3s/60s adaptive)
  ↓ novo METAR detectado
  POST /signal {type: "METAR", tempC, ...}

[Wendy signal.service]
Update runningMaxC = max(runningMaxC, tempC)
bucket = getBucket(runningMaxC)  ← usa máximo, não temp atual
  ↓ bucket > lastBucket (upward cross)
Run guards:
  - hora local dentro do peakRange?
  - price entre $0.05 e $0.75?
  - spread < $0.06?
  - livro com liquidez?
  - daily loss não excedido?
  - station:bucket não locked?
  ↓ guards passaram
BUY new bucket (FOK, verify via getOrder)
  ↓ filled
Log + broadcast trade_executed → Marty

[Jonah] — paralelo, ciclo :48
Ensemble: LightGBM + Chronos + Open-Meteo + RAG → combined probs
Floor filter: remove buckets completamente abaixo do observed_max
GPT-5: recebe probs + METAR + PWS + preços Polymarket → bucket + timing
  ↓ timing MEDIUM/STRONG
POST /trigger {station, bucket, confidence, timing}

[Wendy /trigger]
Fetch tokenId (PayloadCache)
Edge bucket fallback se necessário
Guards (price, spread, liquidity, window, max_1_bucket_jump)
BUY ou ROTATE
  ↓ ROTATE: BUY primeiro, SELL antigo só se bid > $0.03
```

---

## 6. Regras de Trading — Resumo

### Entrada (BUY)

- Apenas upward (running max nunca desce)
- Preço YES: $0.05 ≤ price < $0.75
- Spread ≤ $0.06
- Livro com liquidez
- Dentro da janela de trading (peakRange local)
- Daily loss não excedido
- Station:bucket não locked (previne concurrent trades)
- CLOB: FOK, verificação obrigatória via `getOrder().size_matched`

### ROTATE

- BUY novo primeiro — se falhar, fica no bucket antigo
- SELL antigo: apenas se bid > $0.03
- Jonah trigger: max 1 bucket (2°F) acima do METAR atual
- Downward rotate: sempre bloqueado

### Saída (SELL)

- Jonah dispara SELL quando confidence < 20%
- SELL_STRANDED: quando novo bucket é price_out_of_range e bid do antigo > $0.03
- Nenhuma stop-loss automática — hold até resolução

### Kill Switches / Convergência de Mercado

Três camadas independentes, propósitos distintos:

| Threshold | Sistema                   | Propósito                                                        | Implementado  |
| --------- | ------------------------- | ---------------------------------------------------------------- | ------------- |
| `$0.75`   | Wendy (`guards.ts`)       | Não entrar — risk/reward ruim (max ganho = $0.25)                | ✅            |
| `$0.90`   | Jonah (`predictor.py`)    | Parar GPT-5 — mercado praticamente resolvido, custo desperdiçado | ✅ 2026-04-08 |
| `$1.00`   | Wendy (`market_resolved`) | Mercado resolvido de fato — para de tentar operar                | ✅            |

- `tradingEnabled = false` → bloqueia TODO e qualquer ordem (kill switch manual)

---

## 7. Bugs e Melhorias — Histórico

| Data       | Item                                    | Efeito                                                                                                                                                |
| ---------- | --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-04-06 | SELL_STRANDED ausente                   | Posições perdedoras ficavam abertas quando ROTATE BUY bloqueado por price_out_of_range                                                                |
| 2026-04-08 | Floor enforcement errado em ensemble.py | `int(observed_max)` removia bucket atual. Ex: running_max=71.6 → bucket 70-71 removido → Jonah prediz 72-73 → ROTATE errado saindo da posição correta |
| 2026-04-08 | SELL com bid < $0.03                    | FOK SELL em bucket morto sempre falhava. Agora skip se bid < $0.03                                                                                    |
| 2026-04-06 | Jonah ciclo fixo :48                    | Antes: timer dinâmico pós-METAR. Agora: cron simples às :48 de cada hora                                                                              |
| 2026-04-06 | WS 401 loop                             | Wendy devolvia "Invalid token" no WS. Marty reconectava infinitamente. Agora redireciona para /login                                                  |
| 2026-04-08 | P0 market_converged guard               | Jonah chamava GPT-5 com mercado já a $0.90+. Agora skipa GPT-5 e suprime trigger                                                                      |
| 2026-04-08 | P1 dead bucket METAR guard              | METAR confirmativo entrava em bucket a $0.01 (descartado pelo mercado). Agora skip se yesPrice < $0.05                                                |
| 2026-04-08 | P2 cascade ROTATE guard                 | ROTATEs consecutivos com SELL morto acumulavam N posições perdedoras. Agora bloqueado se openPositions > 1                                            |
| 2026-04-08 | P3 ensemble weights rebalanceados       | OpenMeteo 0.20→0.30, LightGBM 0.30→0.20 (baseado em viés empírico Apr 1-7)                                                                            |
| 2026-04-08 | P4 GPT-5 divergence cap                 | GPT-5 overridava ensemble correto em dias atípicos (KSEA: -14°F). Cap de 4°F implementado                                                             |
| 2026-04-08 | Dead code metarCadence removido (Wendy) | Campo, getter `getMetarCadence()` e cálculo EMA nunca foram usados                                                                                    |
| 2026-04-08 | DB purge nightly implementado (Jonah)   | `purge_old_data(retain_days=90)` deleta metar_readings, pws_readings, session_updates, trigger_history > 90 dias                                      |

---

## 8. Problemas Estruturais — Status

### ✅ P0 — market_converged guard no Jonah (resolvido 2026-04-08)

`predictor.py`: após `fetch_market_prices`, se melhor preço >= $0.90 → flag `market_converged=True` → skip GPT-5. `proxy.py`: suprime /trigger quando `market_converged`. A predição ensemble ainda é salva no DB sem trigger.

### ✅ P1 — METAR confirmativo em buckets descartados (resolvido 2026-04-08)

`signal.service.ts`: guard antes do BUY confirmativo — se `yesPrice < $0.05` → skip com reason `dead_bucket_metar`. O mercado precifica antes do METAR confirmar; entrar em bucket a $0.01 é capital perdido.

### ✅ P2 — ROTATEs em cascata deixam posições mortas (resolvido 2026-04-08)

`signal.service.ts` e `prediction.route.ts`: cascade guard — antes de executar ROTATE, conta posições abertas da estação via `getPositions()`. Se count > 1 (orphan de SELL falho anterior) → skip com reason `cascade_guard`. Auto-recupera quando monitor (3min tick) limpa as posições órfãs.

### ✅ P3 — Pesos ensemble desbalanceados (resolvido 2026-04-08)

OpenMeteo 0.20 → **0.30** (viés -1 a +2°F, empiricamente mais preciso). LightGBM 0.30 → **0.20** (sobre-estima +3 a +10°F sistematicamente).

### ✅ P4 — GPT-5 override destrói ensemble correto em dias atípicos (resolvido 2026-04-08)

**Diagnóstico empírico (Apr 1-7, `sources_accuracy = source_predicted - actual_F`):**

| Fonte      | Viés típico     | Padrão                                                               |
| ---------- | --------------- | -------------------------------------------------------------------- |
| Open-Meteo | -1 a +2°F       | Mais precisa. Peso **0.30**                                          |
| LightGBM   | +3 a +10°F      | Sobre-estima sistematicamente. Peso **0.20**                         |
| Chronos    | Alta variância  | ±12°F possível. Sinal não confiável isolado                          |
| RAG        | Maior variância | Erros de -17 a +17°F. Busca de dias similares falha em dias atípicos |

**Caso KSEA 06/04** (real 72°F, Jonah final 58°F):

- Fontes: Chronos=72°F (perfeito), Open-Meteo=73°F (quase perfeito), LightGBM=78.6°F (+6.6), RAG=78°F (+6)
- Ensemble ponderado ≈ **75°F** (3°F acima do real — correto)
- GPT-5 overridou para **58°F** → erro de 14°F _contra_ o ensemble que estava certo

**Fix:** divergence cap em `predictor.py` — se GPT-5 diverge > 4°F (2 buckets) do ensemble, descarta resultado do GPT-5 e usa ensemble. GPT-5 ainda é chamado para casos dentro do cap.

---

## 9. Banco de Dados

### Wendy (PostgreSQL `wbot_prod`)

- `metar_observations`: histórico completo de METARs com campos meteorológicos
- `trades`: todos os trades com traceId, ação, bucket, tokenId, fillStatus
- `logs`: logs unificados com station, level, category, metadata JSONB
- `app_config`: configuração de trading (tradingEnabled, maxDailyLoss, etc.)
- `auth_sessions`: sessões JWT

**Acesso externo:** `postgresql://postgres:92b2602fbd1205f5@45.93.138.190:15432/wbot_prod`

### Jonah (PostgreSQL `jonah_prod`)

- `day_sessions`: sessão por estação/dia (status, current_bucket, current_confidence)
- `session_updates`: cada update do ciclo (fase, bucket, confidence, sources JSONB)
- `learning_outcomes`: resultados de aprendizado (predicted vs observed, sources_accuracy)
- `trigger_history`: histórico de triggers enviados para Wendy

**Acesso externo:** `postgresql://postgres@45.93.138.190:25432/jonah_prod`

### Retenção / Purge

**Jonah — purge nightly implementado (2026-04-08):** `purge_old_data(retain_days=90)` em `db.py`, chamado ao fim do loop nightly de learning. Deleta de 4 tabelas de alto crescimento:

| Tabela            | Coluna de corte | Crescimento estimado |
| ----------------- | --------------- | -------------------- |
| `metar_readings`  | `captured_at`   | ~240 linhas/dia      |
| `pws_readings`    | `captured_at`   | ~288 linhas/dia      |
| `session_updates` | `created_at`    | ~50-100 linhas/dia   |
| `trigger_history` | `created_at`    | variável             |

`buffer_snapshots` usa `PRIMARY KEY (station)` com UPSERT — apenas 10 linhas (uma por estação), não cresce.

**Wendy — sem purge.** `metar_observations` (~240/dia) e `logs` (~500-2000/dia) crescem sem limite. Candidato a implementar purge nightly via cron externo ou APScheduler.

### Jonah (Qdrant)

- 18.250 pontos (5 anos, 10 estações)
- Cada ponto: date, station, observed_max, temp_probs, conditions, embedding
- Learning nightly: compara predictions vs actuals
- Backfill automático na startup se vazio

---

## 10. Thresholds — Referência Rápida

| Parâmetro                 | Valor              |
| ------------------------- | ------------------ |
| BUY min price             | $0.05              |
| BUY max price             | $0.75              |
| Max spread                | $0.06              |
| Dead bucket bid           | $0.03              |
| METAR fast poll           | 3s                 |
| METAR slow poll           | 60s                |
| PWS poll                  | 300s               |
| Monitor tick              | 3 min              |
| PayloadCache reload       | 30 min             |
| SELL retry max            | 3 tentativas       |
| Daily loss default        | $20                |
| FOK verify attempts       | 5 × 500ms          |
| Jonah cycle               | :48 todo hora UTC  |
| Timing STRONG             | >= 55%             |
| Timing MEDIUM             | >= 40%             |
| Pre-METAR threshold       | >= 70%             |
| SELL threshold            | < 20%              |
| Max bucket jump (trigger) | 1 bucket (2°F)     |
| Floor filter unit         | 2°F (bucket_width) |
| GPT-5 max tokens          | 16384              |
| GPT-5 timeout             | 60s                |
| Market converged (Jonah)  | >= $0.90           |
| Dead bucket METAR (Wendy) | < $0.05            |
| GPT-5 divergence cap      | 4°F (2 buckets)    |
| Cascade guard threshold   | openPositions > 1  |
| DB purge retention        | 90 dias            |

---

_Gerado em: 2026-04-08 | Atualizado: 2026-04-08 (sessão de melhorias estruturais) | Versão: V5 | Branch: main_
