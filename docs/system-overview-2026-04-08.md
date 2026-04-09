# Wozark V5 — System Overview

Documento reconciliado com o codigo local em `2026-04-08`.

Quando houve conflito entre documento antigo e implementacao real, prevaleceu o codigo.

## 1. Resumo executivo

Arquitetura atual:

```text
Ruth  -- POST /signal ----------> Wendy -- REST/WS ----------> Marty
  \                                ^
   \-- POST /signal (copia) ----> Jonah -- /prediction -----> Wendy
                                      \-- /trigger ---------> Wendy
```

Estado operacional real em `2026-04-08`:

- Jonah voltou a ser a camada ativa de entrada pre-METAR.
- Wendy executa `/trigger` sempre; nao existe mais toggle administrativo separado para AI.
- METAR agora atua como confirmacao oficial:
  - mesmo bucket da posicao aberta antes: mantem;
  - bucket diferente: rotaciona;
  - sem posicao pre-METAR: nao compra atrasado.
- PWS continua como camada de contexto, antecipacao analitica e dashboard, sem ordem autonoma.
- A base operacional foi limpa para manter dados a partir de `2026-04-01`.

## 2. Servicos

| Servico | Stack | Papel real |
| --- | --- | --- |
| Ruth | Rust + Tokio + Reqwest | Captura METAR/PWS e publica para Wendy e Jonah |
| Wendy | TypeScript + Fastify 5 + Drizzle | Estado operacional, guards, CLOB, API, analytics e WS |
| Jonah | Python + FastAPI + APScheduler | Ensemble, GPT, learning, RAG e triggers |
| Marty | Next.js + React 19 | Dashboard operacional |

Estacoes ativas:

`KSEA`, `KLAX`, `KSFO`, `KDAL`, `KAUS`, `KHOU`, `KORD`, `KLGA`, `KMIA`, `KATL`

## 3. Ruth

Arquivos-chave:

- `wbot-ruth/src/metar/poller.rs`
- `wbot-ruth/src/metar/parser.rs`
- `wbot-ruth/src/pws/poller.rs`
- `wbot-ruth/src/sender.rs`

### Comportamento atual

- busca a configuracao de estacoes em Wendy
- so roda dentro da janela local operacional
- consulta METAR por estacao e PWS por grupo de sensores
- envia o mesmo payload para Wendy e, opcionalmente, para Jonah

### Polling METAR

Estado real auditado:

- polling rapido default: `3s`
- polling lento: `15s`
- a janela adaptativa aprende o minuto real do METAR, nao o minuto em que o poller detectou
- dedupe nao reinicia mais a cada virada de hora UTC
- logs agora carregam melhor a diferenca entre:
  - hora observada do METAR
  - hora capturada no Ruth

### Contrato

Importante:

- `type` do JSON continua sendo `METAR`
- `SPECI` aparece em `metarType`

Exemplo:

```json
{
  "type": "METAR",
  "station": "KAUS",
  "tempC": 26.7,
  "metarType": "METAR",
  "metarRaw": "METAR KAUS 082253Z ...",
  "metarTime": "2026-04-08T22:53:00Z",
  "capturedAt": "2026-04-08T22:55:39.079Z",
  "traceId": "ruth-metar-kaus-20260408-225539023"
}
```

## 4. Wendy

Arquivos-chave:

- `wbot-wendy/src/modules/signal/signal.service.ts`
- `wbot-wendy/src/modules/signal/prediction.route.ts`
- `wbot-wendy/src/shared/trading/edge.ts`
- `wbot-wendy/src/shared/guards.ts`
- `wbot-wendy/src/shared/db/schema.ts`
- `wbot-wendy/src/shared/db/queries.ts`

### Estado por estacao

O runtime hoje diferencia:

- bucket observado oficialmente (`observedBucket`)
- bucket realmente carregado em posicao (`positionBucket`)
- `runningMaxC`
- `lastTokenId`
- `anticipatedPosition`

Essa separacao era necessaria porque antes o runtime misturava observacao e posicao, o que atrapalhava reconciliacao no METAR.

### Fluxo METAR

Fluxo real de `POST /signal` com `type=METAR`:

1. valida estacao habilitada
2. persiste `metar_observations`
3. publica `new_metar` no WS
4. mede e loga:
   - `upstream lag`
   - `handoff lag`
5. atualiza `runningMaxC` e o bucket observado
6. no primeiro METAR do dia, faz baseline e encerra
7. se nao existir posicao aberta, faz apenas confirmacao/log
8. se existir posicao pre-METAR:
   - bucket igual: hold
   - bucket diferente: rotate para o bucket oficial

Ponto central:

- METAR nao faz mais BUY tardio novo.

### Fluxo `/trigger`

`POST /trigger` agora e o caminho ativo de entrada. Antes de comprar ou rotacionar, Wendy verifica:

- `TRADING_ENABLED`
- estacao habilitada
- limite de salto maximo
- EV minimo (`AI_MIN_EDGE`)
- score minimo da estacao (`AI_RELIABILITY_FLOOR`)
- score minimo do horario local (`hour_underperforming`)
- guards normais de preco, spread, liquidez, janela e daily loss

### Guards ativos

`runGuards()` hoje bloqueia por:

- `outside_trading_window`
- `resolved`
- `price_out_of_range`
- `pws_price_too_high`
- `spread_too_wide`
- `border_zone`
- `no_book_liquidity`
- `daily_loss_exceeded`
- `trade_locked`

### Persistencia

- `metar_observations` agora tem unicidade por `station + valid_utc + metar_raw`
- o indice `uq_metar_station_valid_raw` e garantido tanto no schema quanto no startup

## 5. Jonah

Arquivos-chave:

- `wbot-jonah/src/main.py`
- `wbot-jonah/src/predictor.py`
- `wbot-jonah/src/proxy.py`
- `wbot-jonah/src/learning.py`
- `wbot-jonah/src/rag.py`
- `wbot-jonah/src/db.py`

### Scheduler

Jobs atuais:

- `station_check`: a cada `5 min`
- `save_snapshots`: a cada `2 min`
- `hourly_cycle`: `minute=48`, timezone UTC
- `learning`: `hour=LEARNING_HOUR_UTC`

### Ensemble

As 4 fontes reais continuam:

| Fonte | Peso |
| --- | --- |
| LightGBM | `0.20` |
| Chronos | `0.25` |
| Open-Meteo | `0.30` |
| RAG | `0.25` |

GPT-5 atua como decisor final acima do ensemble, com divergence cap.

### Pre-filters antes do trigger

Antes de chamar Wendy, Jonah filtra:

- mercado convergido
- bucket longe demais do observado
- fora da janela de trading
- rotacao com confianca pior do que a anterior
- horario local com learning ruim

Mesmo quando segura `/trigger`, Jonah continua publicando `/prediction`.

### Learning

`run_learning()`:

1. resolve o resultado do dia
2. persiste `learning_outcomes`
3. atualiza Qdrant
4. purge de dados antigos
5. mantem o LightGBM pre-trained, sem retrain online real

Estado real:

- o learning continuo hoje reforca sobretudo:
  - RAG
  - historico por estacao
  - historico por hora local
- nao existe retrain operacional do LightGBM no runtime atual

### Correcao de `market_snapshot`

Historicamente, `session_updates.market_snapshot` nao estava sendo salvo, o que deixava:

- `market_favorite_bucket = NULL`
- `market_was_correct` pobre
- `jonah_beat_market` inutil no historico antigo

Essa origem foi corrigida em `2026-04-08`, entao o problema passa a se resolver daqui para frente.

## 6. Marty

Marty fala apenas com Wendy.

Pontos relevantes:

- usa REST autenticado e WebSocket
- a station page agora mostra:
  - `METAR observed`
  - `METAR captured`
  - `Publish lag`
  - raw METAR em formato legivel como no TXT da NOAA
- o dashboard operacional passou a expor melhor:
  - PnL por estacao
  - recortes por hora
  - preco medio de entrada
  - bloqueios de AI e METAR

## 7. Thresholds auditados

| Parametro | Valor |
| --- | --- |
| METAR fast poll | `3s` |
| METAR slow poll | `15s` |
| PWS poll | `300s` |
| Circuit breaker open | `10` falhas |
| Circuit breaker backoff | `30s` |
| Retry buffer max | `20` itens |
| Retry TTL | `30s` |
| PayloadCache reload | `30 min` |
| Monitor tick | `3 min` |
| BUY min price | `$0.05` |
| BUY max price | `< $0.75` |
| PWS price ceiling | `>= $0.70` |
| Market converged em Jonah | `>= $0.90` |
| `runGuards()` resolved | `yesPrice >= 1.00` |
| Trigger max jump | `+6°F` ou `+3°C` |
| `AI_MIN_EDGE` default | `0.03` |
| `AI_RELIABILITY_FLOOR` default | `0.45` |
| pre-METAR trigger | `range_prob >= 0.70` |
| SELL threshold Jonah | `< 0.20` |
| GPT timeout | `60s` |
| Divergence cap | `4°F` ou `2°C` |

## 8. Retencao e cleanup

Em `2026-04-08`, o runtime foi limpo para manter dados a partir de `2026-04-01`.

Remocoes executadas:

- Wendy:
  - `18,725` logs
  - `32` trades
  - `1,063` METARs
  - `39,528` PWS snapshots
  - `46` `jonah_triggers`
- Jonah:
  - `14,578` `pws_readings`
  - `931` `metar_readings`
  - `1,177` `session_updates`
  - `40` `day_sessions`

Objetivo:

- reduzir ruido de fase de calibracao antiga
- melhorar analytics
- deixar learning e RAG baseados no periodo mais confiavel do sistema

Limite desta passada:

- o cleanup relacional foi executado
- o Qdrant foi exposto temporariamente e a collection foi corrigida
- `weather_days_v4` foi removida
- `weather_days_v5` foi rebuildada para `18,674` pontos:
  - `18,604` historicos de `data/historical/all_stations.csv`
  - `70` recentes de `learning_outcomes`

## 9. Qualidade atual de learning e RAG

Estado objetivo hoje:

- `learning_outcomes`: utilizavel, mas ainda pequeno
- `station + hour learning`: bom o suficiente para gates simples
- `beat_market_rate`: historico antigo fraco, passa a melhorar a partir da correcao de `market_snapshot`
- `Qdrant weather_days_v5`: historico longo restaurado e camada recente rica mantida por cima

Leitura pratica:

- o learning hoje ja ajuda a cortar horas ruins
- ainda nao sustenta otimizacao agressiva por edge fino
- o RAG voltou a ter profundidade historica, mas a camada recente de learning ainda e curta

## 10. Riscos de negocio ainda abertos

### `max jump` sem fonte canonica

Hoje ainda existe drift entre:

- comentario antigo
- documento antigo
- implementacao real (`+6°F / +3°C`)

### Cutoff de mercado resolvido em tres niveis

- `0.90` em Jonah
- `0.95` em short-circuits de Wendy
- `1.00` em `runGuards()`

### `GPT_PRE_METAR_WINDOW`

- continua presente como configuracao historica
- ainda nao e o mecanismo que governa a decisao real de trigger

### Latencia de METAR publico

Os dados observados em producao continuam apontando atraso estrutural de minutos nos feeds publicos de METAR.

Consequencia:

- o edge principal nao deve depender de "pegar o METAR publico no segundo em que saiu"
- o desenho atual de Jonah pre-METAR + confirmacao oficial do METAR e mais coerente com o que os dados mostram
