# Wozark V5 — System Overview (auditado contra o codigo em 2026-04-08)

Este documento foi reconciliado com o codigo atual dos quatro subprojetos:

- `wbot-ruth/`
- `wbot-wendy/`
- `wbot-jonah/`
- `wbot-marty/`

Quando havia conflito entre texto antigo e implementacao, prevaleceu o codigo. Onde o codigo ainda esta inconsistente ou deixa brechas de negocio/contrato, isso esta marcado como risco aberto.

---

## 0. Resumo Executivo

Arquitetura operacional atual:

```text
Ruth  -- POST /signal ----------> Wendy -- REST/WS ----------> Marty
  \                                ^
   \-- POST /signal (copia) ----> Jonah -- /prediction -----> Wendy
                                      \-- /trigger ---------> Wendy
```

Estado geral verificado:

- Ruth e um sensor puro, mas com resiliencia local: circuit breaker, retry buffer e copia fire-and-forget para Jonah.
- Wendy e a fonte central de estado operacional, execucao de trades, logs, WebSocket e configuracao.
- Jonah roda ensemble de 4 fontes, usa GPT-5 como decisor final com cap de divergencia e envia previsoes/gatilhos para Wendy.
- Marty fala apenas com Wendy via REST e WebSocket autenticado por JWT.
- No modo de producao auditado em `2026-04-08`, a execucao automatica esta restrita a METAR; triggers AI seguem acumulando learning e alimentando `/prediction`, mas ficam bloqueados por default com `AI_TRADING_ENABLED=false`.

Principais divergencias encontradas entre o documento anterior e o codigo:

1. O limite de salto do `/trigger` nao e "1 bucket"; o codigo permite ate `+6°F` ou `+3°C`.
2. O cutoff de mercado "resolvido" nao e unico:
   - `0.90` no Jonah para cortar GPT/trigger
   - `0.95` no Wendy para short-circuit de fluxos METAR/PWS
   - `1.00` no `runGuards()`
3. O campo `metarCadence` citado no documento anterior nao existe mais no `SignalService`.
4. O documento anterior expunha credenciais de banco em texto claro; isso foi removido.
5. O fluxo AI agora bloqueia trigger com `negative_ev` e `station_underperforming`, usando `range_prob` + perfil de learning da estacao.
6. Jonah agora aplica pesos adaptativos por fonte/estacao a partir de `learning_outcomes`, sem depender de retrain do LightGBM.
7. Wendy expoe analytics de entradas resolvidas em `GET /analytics/entries`, com cortes por estacao, hora local, signal type e faixa de preco.

---

## 1. Arquitetura Verificada

### Servicos

| Servico | Stack | Papel real |
| --- | --- | --- |
| Ruth | Rust + Tokio + Reqwest | Captura METAR e PWS, envia para Wendy e opcionalmente para Jonah |
| Wendy | TypeScript + Fastify 5 + Drizzle | Estado de trading, guards, CLOB, API publica e WS |
| Jonah | Python + FastAPI + APScheduler | Predicao, learning, RAG, GPT-5, triggers consultivos |
| Marty | Next.js + React 19 + Zustand | Dashboard operacional |

### Autenticacao entre servicos

Todos os trafegos internos entre Ruth, Wendy e Jonah usam `x-internal-secret` com o valor de `RUTH_SECRET`.

No login, Wendy seta cookie `httpOnly`, mas Marty opera principalmente com Bearer token em REST e `?token=` no handshake do WebSocket.

### Estacoes ativas

As 10 estacoes ativas no codigo atual sao:

`KSEA`, `KLAX`, `KSFO`, `KDAL`, `KAUS`, `KHOU`, `KORD`, `KLGA`, `KMIA`, `KATL`

---

## 2. Ruth — Sensor

Arquivos-chave auditados:

- `wbot-ruth/src/config.rs`
- `wbot-ruth/src/metar/poller.rs`
- `wbot-ruth/src/metar/parser.rs`
- `wbot-ruth/src/pws/poller.rs`
- `wbot-ruth/src/sender.rs`

### Config e janelas

- Ruth busca a lista de estacoes em Wendy via `GET /stations/config`.
- Polling so roda dentro da janela local `04:00 <= hora < 22:00`.
- Defaults atuais:
  - `NOAA_POLL_MS = 3000`
  - `PWS_POLL_MS = 300000`

### METAR polling

- Cada estacao e consultada individualmente em paralelo.
- Polling adaptativo:
  - rapido: `poll_ms` (default `3s`)
  - lento: `60s`
- Enquanto ainda nao aprendeu o minuto de chegada do METAR, fica em polling rapido.
- A janela adaptativa usa o minuto em que Ruth detectou o ultimo METAR, nao o minuto reportado no token `DDHHMMZ`.
- Deduplicacao por chave `ICAO:DDHHMMZ`, com limpeza do `seen` a cada hora UTC.

### PWS polling

- Polling fixo por `poll_ms` (default `300s`).
- Para cada aeroporto, os PWS sao buscados em paralelo via `join_all`.
- Se nenhum PWS retornar leitura valida no ciclo, nada e enviado.

### Contrato de payload

Observacao importante de contrato:

- O topo do payload METAR sempre sai como `type: "METAR"`.
- Quando o raw e `SPECI`, isso vai no campo `metarType: "SPECI"`.
- Ou seja: nenhum consumidor deve esperar `type: "SPECI"` no discriminador do JSON.

Campos relevantes do payload METAR aceito por Wendy:

```json
{
  "type": "METAR",
  "station": "KSEA",
  "tempC": 10.5,
  "tempF": 51,
  "metarType": "METAR",
  "metarRaw": "KSEA 071856Z ...",
  "metarTime": "2026-04-07T18:56:00Z",
  "capturedAt": "2026-04-07T18:56:00.123Z",
  "traceId": "ruth-metar-ksea-20260407-185600123"
}
```

Campos relevantes do payload PWS aceito por Wendy:

```json
{
  "type": "PWS",
  "station": "KSEA",
  "readings": [
    {
      "pwsId": "KWASEATT2476",
      "tempF": 58.7,
      "solarRadiation": 542,
      "uv": 4.1
    }
  ],
  "capturedAt": "2026-04-07T18:56:00.123Z",
  "traceId": "ruth-pws-ksea-20260407-185600123"
}
```

### Resiliencia

- Circuit breaker:
  - abre apos `10` falhas consecutivas
  - backoff de `30s`
- Retry buffer:
  - max `20` payloads
  - TTL `30s`
- Se `JONAH_ENABLED=true`, Ruth envia copia fire-and-forget do mesmo payload para `Jonah /signal`.

---

## 3. Wendy — Brain / Executor

Arquivos-chave auditados:

- `wbot-wendy/src/modules/signal/signal.service.ts`
- `wbot-wendy/src/modules/signal/anticipation.service.ts`
- `wbot-wendy/src/modules/signal/prediction.route.ts`
- `wbot-wendy/src/shared/guards.ts`
- `wbot-wendy/src/modules/rotate/rotate.service.ts`
- `wbot-wendy/src/modules/monitor/monitor.service.ts`
- `wbot-wendy/src/shared/clob/payload-cache.ts`

### Estado em memoria por estacao

Estado real do `SignalService`:

```ts
{
  runningMaxC: number
  lastTempC: number
  maxTempC6h: number | null
  lastBucket: string | null
  lastTokenId: string | null
  confirmedBuckets: Set<string>
  lastDate: string | null
  lastMetarAt: Date | null
  anticipatedPosition: {
    bucketLabel: string
    normalizedBucket: string
    tokenId: string
    shares: number
    traceId: string
  } | null
}
```

Nao existe mais:

- `metarCadence`
- `getMetarCadence()`

O documento anterior tratava isso como se ainda estivesse no runtime. Nao esta.

### Bucketizacao

Para mercados Fahrenheit, Wendy usa `Math.round()` antes de snap para bucket par-impar:

```ts
f = Math.round(c * 9 / 5 + 32)
low = f % 2 === 0 ? f : f - 1
label = `${low}-${low + 1}°F`
```

Exemplo:

- `21.4°C` -> `70.5°F` -> `Math.round = 71` -> bucket `70-71°F`

### Fluxo `POST /signal` para METAR

Fluxo real de `processMetar()`:

1. Valida se a estacao esta habilitada.
2. Salva METAR no banco em fire-and-forget.
3. Broadcast `new_metar` para Marty.
4. Detecta mudanca de dia local e reseta:
   - `runningMaxC`
   - `lastTempC`
   - `maxTempC6h`
   - `lastMetarAt`
   - `lastBucket`
   - `lastTokenId`
   - `confirmedBuckets`
   - `anticipatedPosition`
5. Atualiza:
   - `lastTempC = temp atual`
   - `lastMetarAt = now`
   - `runningMaxC = max(runningMaxC, temp atual)`
6. Valida eventual posicao antecipada de PWS.
7. Se algum mercado do evento ja estiver `>= 0.95`, encerra o fluxo sem trade.
8. Calcula bucket pelo `runningMaxC`, nao pela temperatura atual.
9. Se o bucket nao mudou, so loga e retorna.
10. Se o bucket desceu, apenas atualiza tracking; nao dispara trade.
11. No primeiro METAR do dia/restart, faz baseline e retorna.
12. Decide entre:
    - `SKIP` se o pre-METAR ja esta no mesmo bucket
    - `HOLD` se METAR veio igual/abaixo do bucket comprado antes
    - `ROTATE` se METAR confirmou bucket acima do pre-METAR
    - `BUY` confirmativo se nao havia posicao pre-METAR
13. Faz fallback de bucket extremo (`or higher` / `or lower`) se necessario.
14. Aplica guard de bucket morto para entrada confirmativa:
    - se `yesPrice < 0.05`, retorna `dead_bucket_metar`
15. Busca payload/order book e roda guards.
16. Se for ROTATE:
    - bloqueia cascata se houver mais de uma posicao aberta na estacao
    - compra bucket novo primeiro
    - so depois tenta vender o antigo
17. Broadcasts e persistencia de trade sao feitos nos services de BUY/SELL.

### SELL_STRANDED

Quando uma rotacao METAR e bloqueada por `price_out_of_range`:

1. Wendy tenta vender a posicao antiga mesmo assim.
2. Se o `bid` antigo for `< 0.03`, abandona a venda.
3. Se houver posicao real e `bid >= 0.03`, executa `SELL_STRANDED`.

### Fluxo PWS em Wendy

O PWS nao opera autonomamente hoje, mas nao e apenas "data-only" no sentido estrito.

O que `AnticipationService` realmente faz:

- persiste snapshot PWS em `pws_observations`
- mantem historico de 15 min em memoria
- mantem `pwsPeaks` diarios por `pwsId`
- broadcasta `pws_update` para Marty
- calcula:
  - `gap`
  - `conf`
  - `ramp`
  - `score`
  - `strength`
  - `tEstimated`
  - `predicted bucket`

O que ele nao faz:

- nao chama BUY
- nao chama ROTATE
- nao dispara ordem alguma

Observacao importante:

- O feed para Jonah nao sai de Wendy.
- Quem envia PWS para Jonah e o proprio Ruth, via copia fire-and-forget em `sender.rs`.

### Guards realmente ativos

`runGuards()` hoje bloqueia por:

| Reason | Regra real |
| --- | --- |
| `outside_trading_window` | hora local fora do `peakRange` |
| `resolved` | `yesPrice >= 1.0` |
| `price_out_of_range` | `yesPrice < 0.05` ou `yesPrice >= 0.75` |
| `pws_price_too_high` | apenas se `signalType === "PWS"` e `yesPrice >= 0.70` |
| `border_zone` | temperatura em zona de fronteira |
| `no_book_liquidity` | `book` ausente ou sem bids |
| `daily_loss_exceeded` | apenas quando `!isRotate` |
| `trade_locked` | `station:bucket` ja em execucao |

O que existe no arquivo, mas nao esta sendo aplicado:

- `isSpreadTooWide()`
- `MAX_SPREAD = 0.06`
- reason `spread_too_wide`

No codigo atual auditado, esse guard ja esta ativo em `runGuards()`.

### Fluxo `POST /trigger` (Jonah -> Wendy)

Fluxo real:

1. Autentica `x-internal-secret`.
2. Valida `TriggerSchema`.
3. Bloqueia se `tradingEnabled=false`, `aiTradingEnabled=false` ou estacao desabilitada.
4. Se `signal="SELL"`, tenta vender a posicao atual da estacao.
5. Para BUY/STRONG:
   - carrega payload do `PayloadCache`
   - faz fallback de bucket extremo se necessario
   - ignora se ja esta segurando o mesmo `tokenId`
   - roda guards
   - escala tamanho:
     - `MEDIUM` -> `50%`
     - `STRONG` -> `100%`
   - faz BUY ou ROTATE
6. Persiste o resultado em `jonah_triggers`.

Com `AI_TRADING_ENABLED=false`:

- `/prediction` continua ativo
- dashboard continua recebendo previsoes e learning
- Jonah continua produzindo advisory e acumulando historico
- `/trigger` responde bloqueado com reason `ai_trading_disabled`

### Regra real de salto maximo do trigger

O codigo atual nao implementa "max 1 bucket".

Ele permite:

- Fahrenheit: bucket-alvo ate `currentF + 6`
- Celsius: bucket-alvo ate `current + 3`

Isso aparece em dois pontos:

- `wbot-jonah/src/proxy.py`
- `wbot-wendy/src/modules/signal/prediction.route.ts`

Observacao importante:

- Os comentarios nesses arquivos falam em "2 buckets", mas `+6°F` equivale a 3 buckets Fahrenheit de 2 graus.
- O documento antigo falava em "1 bucket".
- A regra de negocio precisa de uma versao canonica; hoje texto, comentario e implementacao nao batem.

### High-confidence early bypass

`/trigger` permite bypass da janela inicial se:

- `confidence >= 0.95`
- e o horario local ainda estiver antes do inicio do `peakRange`

Depois do fim da janela nao ha bypass.

### Protecao de confianca entre triggers

Existe uma protecao contra rotacionar para bucket diferente com qualidade pior no lado Jonah:

- `wbot-jonah/src/proxy.py`

No codigo atual auditado, Wendy tambem repete essa validacao em `/trigger` usando o ultimo `jonah_trigger` persistido.

Impacto de contrato:

- o contrato fica mais resistente mesmo para callers internos que nao passem pelo proxy do Jonah.

### ROTATE

Implementacao atual:

1. BUY do bucket novo
2. se BUY falhar, para tudo
3. se BUY passar:
   - consulta `bid` do bucket antigo
   - se `bid < 0.03`, nao vende
   - senao executa SELL do antigo

### PayloadCache

Comportamento real:

- carrega na startup
- recarrega a cada `30 min`
- monta `Map` novo a cada reload
- `fire()` mistura payload estatico com book fresco

Observacao:

- existe comentario em `server.ts` falando em refresh "every 60s", mas o codigo real esta em `30 min`.

### Monitor

`MonitorService` roda a cada `3 min` e faz:

1. refresh de snapshots de mercado
2. reconciliacao de posicoes reais vs estado interno
3. deteccao de duplicatas reais por `station:tokenId`
4. fila de `SELL` retry com max `3` tentativas

Erros terminais descartados sem retry:

- mensagens contendo `not enough balance`
- mensagens contendo `allowance`

---

## 4. Jonah — Analyst / Learning

Arquivos-chave auditados:

- `wbot-jonah/src/main.py`
- `wbot-jonah/src/predictor.py`
- `wbot-jonah/src/ensemble.py`
- `wbot-jonah/src/gpt.py`
- `wbot-jonah/src/proxy.py`
- `wbot-jonah/src/learning.py`
- `wbot-jonah/src/db.py`

### Entrada de sinais

`POST /signal` em Jonah recebe copia de Ruth e faz:

- METAR:
  - atualiza buffer sempre
  - salva no banco apenas quando `metar_raw` muda
  - atualiza historico de chegada do METAR para heartbeat
- PWS:
  - atualiza buffer sempre
  - salva toda leitura no banco

Observacao:

- existe docstring antiga em `main.py` sugerindo throttle de PWS por 5 min / 1 min, mas o codigo atual salva toda leitura.

### Scheduler

Jobs atuais no APScheduler:

- `station_check`: intervalo de `5 min`
- `save_snapshots`: intervalo de `2 min`
- `hourly_cycle`: cron `minute=48`, timezone UTC
- `learning`: cron `hour=LEARNING_HOUR_UTC`

`hourly_cycle` em `:48` faz:

- `run_dawn()` para quem ainda nao tem dawn no dia
- `_pre_metar_prediction()` para sessoes ativas

### Ensemble

As 4 fontes reais sao:

| Fonte | Peso atual |
| --- | --- |
| LightGBM | `0.20` |
| Chronos | `0.25` |
| Open-Meteo | `0.30` |
| RAG | `0.25` |

### Floor monotono

`combine_sources()` remove apenas buckets totalmente abaixo do observado:

```py
bucket_width = 2 if unit == "F" else 1
removed = {k: v for k, v in combined.items() if k + bucket_width <= observed_max}
```

Isso corrige o bug em que o bucket atual era removido cedo demais.

### GPT-5

Implementacao atual em `gpt.py`:

- OpenAI SDK: `AsyncOpenAI`
- timeout: `60s`
- chamada em `chat.completions.create`
- `max_completion_tokens = 16384`
- `response_format = {"type": "json_object"}`

Fallback atual:

- se houver erro de quota/rate-limit e `ANTHROPIC_API_KEY` estiver configurada
- Jonah cai para `claude-sonnet-4-6`

### Divergence cap

Se GPT divergir demais do ensemble:

- Fahrenheit: mais de `4°F`
- Celsius: mais de `2°C`

Jonah descarta o GPT e mantem o ensemble.

### Market-converged guard

Se o melhor bucket de mercado ja estiver `>= 0.90`:

- Jonah nao chama GPT-5
- Jonah nao envia trigger
- ainda assim a previsao/advisory continua sendo salva

### Thresholds de timing

`ensemble.py` hoje usa:

| Timing | Threshold |
| --- | --- |
| `STRONG` | `>= 0.55` |
| `MEDIUM` | `>= 0.40` |
| `SMALL` | `>= 0.30` |
| `WAIT` | `< 0.30` |

No `proxy.py`:

- `MEDIUM` e `STRONG` viram trigger de BUY
- `pre_metar` exige `range_prob >= 0.70`
- `SELL` e disparado quando a confianca do mesmo bucket cai abaixo de `0.20`

### Regras pre-filter no proxy

Antes de bater em Wendy, Jonah pre-filtra:

- mercado convergido
- bucket distante demais do observado
- fora da janela de trading, exceto bypass cedo com `>= 95%`
- rotacao para bucket diferente com `range_prob` pior ou igual ao ultimo trigger

Importante:

- essa ultima regra nao e revalidada por Wendy

### Learning e purge

`run_learning()` hoje:

1. resolve outcomes do dia por estacao
2. salva `learning_outcomes`
3. atualiza RAG/Qdrant
4. faz purge de dados antigos
5. chama `_retrain_lgbm()`

Estado real do retrain:

```py
async def _retrain_lgbm():
    logger.info("LightGBM retrain: skipped (using pre-trained models)")
```

Ou seja:

- o learning nao retreina LightGBM hoje
- o que aprende continuamente e, na pratica, o lado RAG/memoria

Purge noturno implementado:

- retencao: `90 dias`
- tabelas:
  - `metar_readings`
  - `pws_readings`
  - `session_updates`
  - `trigger_history`

---

## 5. Marty — Dashboard

Rotas auditadas em `wbot-marty/app/`:

- `/`
- `/login`
- `/positions`
- `/logs`
- `/settings`
- `/status`
- `/learning`
- `/report`
- detalhe de estacao em `app/station/[icao]`

### WebSocket

Eventos definidos no broadcaster de Wendy:

- `new_metar`
- `pws_update`
- `trade_executed`
- `trade_skipped`
- `new_log`
- `error`
- `position_update`
- `market_update`
- `position_synced`
- `ai_prediction`
- `gpt_meta`
- `gpt_prediction`

Eventos realmente broadcastados no codigo auditado:

- `new_metar`
- `pws_update`
- `trade_executed`
- `trade_skipped`
- `new_log`
- `position_update`
- `market_update`
- `position_synced`
- `ai_prediction`

Envelope real publicado por Wendy:

```json
{
  "type": "new_metar",
  "data": {},
  "timestamp": "2026-04-08T12:00:00.000Z"
}
```

### Auth de WS

Wendy exige token JWT no query param `token` ou header `Authorization`.

Se o token for invalido:

- Wendy fecha com `4003 Invalid token`
- Marty trata erro de auth e faz logout/redirecionamento

---

## 6. Bancos e Persistencia

### Wendy DB

Tabelas reais em `wbot-wendy/src/shared/db/schema.ts`:

- `metar_observations`
- `pws_observations`
- `trades`
- `logs`
- `app_config`
- `jonah_triggers`
- `auth_sessions`

Observacoes:

- o documento anterior omitia `pws_observations`
- o documento anterior omitia `jonah_triggers`

### Jonah DB

Tabelas reais em `wbot-jonah/src/db.py`:

- `metar_readings`
- `pws_readings`
- `day_sessions`
- `session_updates`
- `learning_outcomes`
- `buffer_snapshots`
- `trigger_history`

### Seguranca documental

Este documento nao deve conter:

- URLs externas com senha
- DSNs completos de banco
- segredos de servico

Esses dados pertencem ao `.env` e ao runtime, nao a documentacao do workspace.

---

## 7. Thresholds Verificados no Codigo

| Parametro | Valor real |
| --- | --- |
| METAR fast poll | `3s` default |
| METAR slow poll | `60s` |
| PWS poll | `300s` default |
| Circuit breaker open | `10` falhas |
| Circuit breaker backoff | `30s` |
| Retry buffer max | `20` itens |
| Retry TTL | `30s` |
| PayloadCache reload | `30 min` |
| Monitor tick | `3 min` |
| BUY min price | `$0.05` |
| BUY max price | `< $0.75` |
| Dead bucket sell skip | `bid < $0.03` |
| Market converged em Jonah | `>= $0.90` |
| Short-circuit de mercado em Wendy METAR/PWS | algum mercado `>= $0.95` |
| `runGuards()` resolved | `yesPrice >= 1.00` |
| Daily loss default | `$50` |
| Daily loss aplicada em ROTATE | `nao` |
| Order verify attempts | `5` |
| Base delay de verify | `500ms` |
| Trigger BUY MEDIUM | `50%` do `tradingMaxSize` |
| Trigger BUY STRONG | `100%` do `tradingMaxSize` |
| Trigger max jump | `+6°F` ou `+3°C` |
| AI trading enabled default | `false` |
| AI min edge default | `0.03` |
| AI reliability floor default | `0.45` |
| Pre-METAR trigger threshold | `>= 70%` |
| SELL threshold em Jonah | `< 20%` |
| GPT timeout | `60s` |
| GPT max completion tokens | `16384` |
| Divergence cap | `4°F` ou `2°C` |

---

## 8. Problemas de Negocio / Contrato Ainda Abertos

### 8.1 Regra de max jump do `/trigger` esta sem fonte canonica

Hoje existem tres narrativas diferentes:

- documento antigo: `1 bucket`
- comentarios no codigo: `2 buckets`
- implementacao real: `+6°F / +3°C`

Impacto:

- risco de operar buckets mais distantes do que o esperado pela estrategia
- dificulta backtesting e revisao operacional

### 8.2 Cutoff de "mercado resolvido" nao e unico

Valores atuais:

- `0.90` -> Jonah corta GPT/trigger
- `0.95` -> Wendy METAR/PWS para processamento de trade
- `1.00` -> `runGuards()` retorna `resolved`

Impacto:

- a mesma situacao de mercado pode ser classificada de formas diferentes dependendo do caminho
- dificulta logs, analytics e explicacao operacional

### 8.3 Contrato METAR/SPECI precisa ser explicitado

Status:

- discriminador JSON sempre e `type: "METAR"`
- `SPECI` vai em `metarType`

Impacto:

- qualquer consumidor novo que dependa do `type` para separar METAR vs SPECI vai errar

### 8.4 Drift de comentarios e configuracoes nao usadas

Itens encontrados:

- comentario de `PayloadCache` em `server.ts` fala em `60s`, codigo real usa `30 min`
- docstring de `/signal` em Jonah fala em throttle de PWS, codigo salva tudo
- `GPT_PRE_METAR_WINDOW` existe em config, mas nao apareceu em uso no codigo auditado

Impacto:

- manutencao mais lenta
- operador e desenvolvedor tomando decisao em cima de comentario errado

---

## 9. O que foi corrigido neste documento

Em relacao a versao anterior, esta revisao:

- removeu o estado ficticio de `metarCadence`
- corrigiu os guards realmente ativos
- corrigiu o tamanho real do `PayloadCache` reload
- corrigiu o threshold real de `maxDailyLoss` default
- corrigiu o fluxo PWS em Wendy para "analitico sem trade", nao "pass-through puro"
- corrigiu o salto maximo real do `/trigger`
- incluiu as tabelas `pws_observations` e `jonah_triggers`
- removeu segredos e DSNs sensiveis do texto
- separou claramente o que esta implementado do que ainda e risco aberto

---

Gerado a partir do codigo local em 2026-04-08.
