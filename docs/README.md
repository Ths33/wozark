# Wozark — Documentacao Canonica

Atualizado em 2026-08-09.

Este e o documento completo e autocontido do projeto Wozark. Ele substitui os
documentos antigos de arquitetura, schema e catalogo. Se houver divergencia
entre esta documentacao e o codigo em producao, o codigo vence e este documento
deve ser atualizado no mesmo patch.

## 1. Resumo

Wozark e um sistema de auto-trading para mercados de temperatura maxima diaria
em Polymarket. O objetivo operacional e detectar novas maximas diarias antes de
bots que dependem apenas do METAR horario oficial, comprar o bucket correto
rapidamente e acompanhar a operacao em tempo real.

O sistema tem quatro servicos:

| Servico | Stack | Porta | Papel |
| --- | --- | ---: | --- |
| Ruth | Rust, Axum, Tokio | 8080 | Sensor meteorologico. Captura observacoes e publica sinais. |
| Wendy | TypeScript, Fastify 5, Drizzle, Postgres | 3000 | Cerebro de trading. Decide e executa BUY/SELL/ROTATE. |
| Marty | Next.js 16, React 19, Recharts | 80 | Dashboard operacional em tempo real. |
| Jonah | Python 3.12, FastAPI, LightGBM, Chronos, Qdrant, GPT-5 | 8000 | Analista de previsao e aprendizado. Atualmente learning-only. |

Fluxo atual:

```text
Synoptic /timeseries + TGFTP + Weather Underground PWS
  -> Ruth
  -> Wendy /signal               METAR/Synoptic fresh sensor, trading
  -> Jonah /signal               METAR + PWS, learning
  -> Jonah /prediction -> Wendy  advisory, sem trade
  -> Wendy REST/WS -> Marty      dashboard
```

## 2. Principios do Projeto

1. O edge central nao e parsear METAR mais rapido. O edge e usar leituras
   frescas de sensor do Synoptic antes do METAR horario confirmar a maxima.
2. Ruth e sensor puro. Ela nao decide trade, nao calcula bucket e nao escreve em
   banco.
3. Wendy e a unica executora de trading real.
4. Marty nunca acessa banco. Tudo passa por Wendy.
5. Jonah nao executa trades no estado atual. Ele aprende, prediz e publica
   advisory.
6. Codigo vence documento. Fluxos de trading precisam ser confirmados no codigo
   antes de alteracao ou explicacao.
7. Mudanca em contrato HTTP, payload, header ou evento WebSocket deve ser
   revisada nos quatro servicos.
8. Trading logic e area de alto risco. Mudar guard, sizing, bucket, rotate,
   CLOB ou stop/exit exige leitura completa da funcao afetada e teste local.
9. Hipoteses devem ser tratadas como hipoteses. Sem backtest ou metrica, nao
   chamar uma alteracao de solucao comprovada.
10. Deploy significa `git push` para o branch monitorado pelo CapRover, sempre
    apos build/test do servico afetado.

## 3. Estado Operacional Atual

- Ruth usa Synoptic `/timeseries?recent=120` como fonte primaria.
- Ruth tambem usa TGFTP como fallback e em slots paralelos para T-group.
- Ruth envia METAR/Synoptic para Wendy e Jonah.
- Ruth envia PWS somente para Jonah.
- Wendy processa sinais de Ruth e pode executar BUY/ROTATE quando ha cruzamento
  de bucket e os guards passam.
- Wendy nao deve receber PWS como gatilho de trade.
- Wendy nao usa BUY NO / harvest. Rotacao compra o bucket novo primeiro e tenta
  vender o bucket antigo.
- Wendy nao deve reintroduzir `/trigger` como caminho de execucao de Jonah sem
  decisao explicita.
- Jonah esta em learning-only: `TRIGGER_ENABLED = False`.
- Jonah envia `/prediction` para Wendy apenas como advisory.
- Marty mostra estado, logs, decisoes, posicoes, config, aprendizado e spread.
- Todos os horarios de UI em Marty sao BRT, exceto um chip unico de horario
  local da estacao.

## 4. Estacoes

As 10 estacoes operacionais:

| Cidade | ICAO | Timezone local | Uso |
| --- | --- | --- | --- |
| Seattle | KSEA | America/Los_Angeles | METAR trading, Jonah, Marty, spread habilitado |
| Los Angeles | KLAX | America/Los_Angeles | METAR trading, Jonah, Marty, spread habilitado |
| San Francisco | KSFO | America/Los_Angeles | METAR trading, Jonah, Marty |
| Dallas | KDAL | America/Chicago | METAR trading, Jonah, Marty |
| Austin | KAUS | America/Chicago | METAR trading, Jonah, Marty |
| Houston | KHOU | America/Chicago | METAR trading, Jonah, Marty |
| Chicago | KORD | America/Chicago | METAR trading, Jonah, Marty |
| New York | KLGA | America/New_York | METAR trading, Jonah, Marty |
| Miami | KMIA | America/New_York | METAR trading, Jonah, Marty, spread habilitado |
| Atlanta | KATL | America/New_York | METAR trading, Jonah, Marty, spread habilitado |

Regras de exibicao:

- UI deve mostrar cidade como identificador principal.
- ICAO pode aparecer como detalhe secundario.
- Horarios operacionais na UI usam BRT.

## 5. Arquitetura de Runtime

```text
External APIs
  Synoptic Data
  TGFTP NOAA static METAR text
  Weather Underground PWS
  Polymarket Gamma API
  Polymarket CLOB
  Open-Meteo
  NWS
  OpenAI GPT-5
  Claude fallback
        |
        v
Ruth -> Wendy -> Polymarket CLOB
  \       |
   \      v
    -> Jonah -> Wendy -> Marty
             advisory     REST + WebSocket
```

Comunicacao interna:

| Origem | Destino | Metodo | Auth | Finalidade |
| --- | --- | --- | --- | --- |
| Ruth | Wendy | `POST /signal` | `x-internal-secret` | Sinal METAR/Synoptic para trading |
| Ruth | Wendy | `POST /log` | `x-internal-secret` | Eventos diagnosticos |
| Ruth | Jonah | `POST /signal` | `x-internal-secret` | METAR/PWS para aprendizado |
| Jonah | Wendy | `POST /prediction` | `x-internal-secret` | Advisory para dashboard |
| Marty | Wendy | REST | JWT | Dados, config, ordens manuais |
| Marty | Wendy | WebSocket | JWT query param | Atualizacoes em tempo real |

Hosts internos de producao:

| Servico | Host interno |
| --- | --- |
| Wendy | `srv-captain--wendy:3000` |
| Jonah | `srv-captain--jonah:8000` |
| Wendy Postgres | `srv-captain--wbot-db:5432` |
| Jonah Postgres | `srv-captain--jonah-db:5432` |
| Qdrant | `srv-captain--qdrant:6333` |

## 6. Ruth

### Papel

Ruth e o sensor do sistema. Ela coleta observacoes meteorologicas e as publica
com baixa latencia para Wendy e Jonah. Ruth nao decide trade.

### Fontes

| Fonte | Uso | Observacao |
| --- | --- | --- |
| Synoptic `/timeseries?recent=120` | Primaria | Leituras frescas de sensor, varias observacoes por janela |
| TGFTP NOAA | Fallback e paralelo em slots especificos | Texto METAR estatico, sem rate limit relevante |
| Weather Underground PWS | Contexto para Jonah | Nunca vai para Wendy |

### Scheduler

Slots principais por hora UTC:

```text
:00, :05, :10, :15, :20, :25, :30, :35, :40, :45, :50, :51, :53, :55
```

Hot-poll:

- Janela: `:50` a `:58`.
- Intervalo: 3 segundos.
- Finalidade: capturar T-group assim que aparece.
- TGFTP pode ser consultado em paralelo nessa janela.

### Regras de dado

- `tempC` vem da leitura fresca do Synoptic.
- `metarTime`/`validUtc` vem do timestamp real da observacao.
- `metarRaw` e usado para enriquecer cloud layers, visibility e sea level
  pressure.
- Parsing do texto METAR nao deve sobrescrever temperatura/timestamp frescos.
- Dedup e feito por observacao/timestamp para evitar replay.

### Payload METAR

```text
type = METAR
station
tempC
tempF
dewpointC
humidityPct
windDeg
windKt
gustKt
visibilityM
cloudLayers
pressureHpa
ceilingFt
wxString
autoStation
metarType
source
metarRaw
metarTime
capturedAt
traceId
tempPrecise
```

### Payload PWS

```text
type = PWS
station
traceId
capturedAt
readings[]
```

Cada reading PWS carrega:

```text
pwsId
tempF
humidity
windSpeed
windGust
windDir
dewpointF
pressure
solarRadiation
uv
precipRate
precipTotal
obsTime
```

### Resiliencia

- Rotacao de tokens Synoptic em falha.
- Batch de ate 5 estacoes por chamada Synoptic.
- Retry por estacao antes de fallback TGFTP.
- Circuit breaker no envio para Wendy.
- Retry buffer para Wendy com TTL.
- Envio para Jonah fire-and-forget com retry simples.
- Rate limit Synoptic pausa hot-poll temporariamente.

### Comandos

```bash
cargo build --release
cargo test
cargo fmt
cargo clippy
cargo run
```

### Variaveis de ambiente

```env
WENDY_URL=http://srv-captain--wendy:3000
JONAH_URL=http://srv-captain--jonah:8000
JONAH_ENABLED=true
RUTH_SECRET=<shared-secret>
PWS_POLL_MS=300000
WU_API_KEY=<weather-underground-api-key>
RUST_LOG=wbot_ruth=info
```

## 7. Wendy

### Papel

Wendy e o cerebro de trading. Ela recebe sinais de Ruth, atualiza estado,
calcula bucket, aplica guards, executa ordens no CLOB, persiste eventos e
transmite atualizacoes para Marty.

### Fluxo de sinal

```text
POST /signal
  -> validar payload
  -> calcular lag diagnostico
  -> salvar observacao em Postgres sem bloquear hot path
  -> broadcast new_metar
  -> atualizar runningMaxC
  -> calcular bucket
  -> checar tradingEnabled e metarTradingEnabled
  -> aplicar guards
  -> BUY ou ROTATE
  -> broadcast trade_executed ou trade_skipped
```

### Estado por estacao

| Campo | Significado |
| --- | --- |
| `runningMaxC` | Maxima diaria observada, monotonicamente crescente |
| `lastMetarAt` | Timestamp real da observacao |
| `lastTokenId` | Token/bucket atualmente carregado |
| `lastBucket` | Bucket observado anterior |
| `sustainedAutoStreak` | Controle para leituras AUTO/imprecisas |

### Regras de trading

- `tradingEnabled=false` e kill switch absoluto.
- `metarTradingEnabled=false` bloqueia trades por sinal.
- `runningMaxC` so avanca com leitura real de sensor.
- Cruzamento de bucket pode gerar BUY.
- Bucket diferente com posicao aberta pode gerar ROTATE.
- ROTATE compra novo primeiro; se BUY falhar, nao vende o antigo.
- Border zone de preco `0.45-0.55` e skip.
- Daily loss cap bloqueia novos BUYs nao-rotate.
- Trade lock evita concorrencia por `station:bucket`.
- FOK deve ser verificado via `getOrder().size_matched`.
- GTC fallback existe quando FOK nao preenche de forma adequada.
- No stop-loss automatico estrutural; posicoes tendem a hold/resolution salvo
  rotacao, sell manual, auto-sell ou monitor.
- BUY NO / harvest nao deve voltar.
- Jonah prediction e advisory, nao gatilho de execucao.

### Guards

Guards usados no caminho de trade:

```text
outside_trading_window
resolved
price_out_of_range
pws_price_too_high
spread_too_wide
border_zone
no_book_liquidity
daily_loss_exceeded
trade_locked
```

Ordem esperada: checks locais baratos primeiro, chamada de book/mercado apenas
quando necessario.

### Caches de latencia

- Gamma market cache: cerca de 5 minutos.
- Book snapshot cache: cerca de 30 segundos.
- Payload/order metadata cache: cerca de 30 minutos.
- DB writes no hot path devem ser fire-and-forget quando o resultado nao e
  necessario para executar a ordem.

### Monitor

Tick operacional a cada 3 minutos:

- Atualiza precos de posicoes ativas.
- Detecta e limpa duplicatas.
- Processa retry de SELL.
- Pode auto-vender proximo de resolucao.
- Sincroniza estado operacional com CLOB.

### Endpoints

| Metodo | Path | Auth | Uso |
| --- | --- | --- | --- |
| GET | `/health` | Publico | Liveness |
| GET | `/system/status` | Publico | Status operacional |
| POST | `/signal` | Internal secret | Sinais Ruth |
| POST | `/prediction` | Internal secret | Advisory Jonah |
| POST | `/log` | Internal secret | Logs Ruth |
| GET | `/stations/config` | Internal secret | Config de estacoes para Ruth |
| POST | `/learning/run` | Internal secret | Trigger manual learning |
| POST | `/auth/login` | Publico | Login Marty |
| GET | `/auth/status` | JWT | Estado da sessao |
| GET | `/stations` | JWT | Board de estacoes |
| GET | `/data/:station` | JWT | Detalhe de estacao |
| GET | `/metar/:station/history` | Publico | Historico intraday |
| GET | `/positions` | JWT | Posicoes |
| GET | `/balance` | JWT | Saldo e gasto diario |
| GET | `/report` | JWT | Relatorio diario |
| GET | `/logs` | JWT | Logs filtraveis |
| GET | `/config` | JWT | Config trading |
| POST | `/config` | JWT | Atualizar config |
| GET | `/analytics/entries` | JWT | Analitico de entradas |
| GET | `/analytics/operations` | JWT | Pressao de guards |
| GET | `/ops/pnl` | JWT | PnL do dia |
| GET | `/ops/latency` | JWT | Latencia signal->trade |
| POST | `/buy` | JWT | Compra manual |
| POST | `/sell` | JWT | Venda manual |
| GET | `/jonah/overview` | JWT | Proxy overview Jonah |
| GET | `/learning/metrics` | JWT | Metricas Jonah |
| GET | `/learning/debug` | JWT | Debug learning |
| GET | `/shadow/summary` | JWT | Simulador shadow |
| GET | `/shadow/trades` | JWT | Trades shadow |
| GET | `/spread/positions` | JWT | Spread shadow |
| GET | `/spread/summary` | JWT | Resumo spread |
| GET | `/spread/eval/per-station` | JWT | ROI por estacao |
| GET | `/spread/eval/by-bucket-index` | JWT | ROI por indice |
| POST | `/spread/live-prices` | JWT | Batch prices |
| POST | `/spread/scan-now` | JWT | Scan manual |
| POST | `/spread/monitor-now` | JWT | Monitor manual |
| POST | `/spread/resolve-now` | JWT | Resolve manual |
| POST | `/spread/re-resolve-all` | JWT | Recalcular resultados |
| POST | `/spread/dedupe-cohorts` | JWT | Dedup cohorts |
| POST | `/spread/snapshot-now` | JWT | Snapshot Polymarket |
| WS | `/ws` | JWT query | Eventos real-time |

### WebSocket events

```text
new_metar
trade_executed
trade_skipped
position_update
position_synced
market_update
new_log
error
ai_prediction
```

### Spread shadow trader

Modulo paralelo ao METAR trading. Nao executa CLOB real.

Estado atual:

- Estrategia ativa: `spread-v3-2026-05-05`.
- Estacoes habilitadas: KATL, KLAX, KMIA, KSEA.
- Estacoes desabilitadas no spread: KORD, KAUS, KDAL, KLGA, KHOU, KSFO.
- Cohort: 2 buckets com offsets `[-1, 0]` contra forecast D+2.
- Stake hipotetico: `$2` por leg.
- Skip de leg se ask `< $0.05` ou `> $0.60`.
- Skip de cohort se mercado estiver polarizado.
- Exit A apenas em `bucket_index = -1`.
- Exit B por invalidacao.
- Exit C em `bucket_index = 0`, hold-to-resolution.
- Tabelas principais: `spread_shadow_trades`, `polymarket_market_trades`.

Aprendizado de spread:

- v1 foi negativo em amostra curta.
- v2 removeu Exit A e melhorou em alguns recortes.
- v2.5 reintroduziu Exit A somente em idx -1 apos breakdown por indice.
- v3 reduziu whitelist e stake para paper mais conservador.
- Backtests eram promissores em partes, mas amostras pequenas exigem observacao
  em producao antes de escalar.

### Comandos

```bash
npm install
npm run dev
npm run build
npm test
npm run lint
npm run lint:fix
npm run format
npm run format:check
npm run db:push
```

### Variaveis de ambiente

```env
DATABASE_URL=postgresql://...@srv-captain--wbot-db:5432/wbot_prod
RUTH_SECRET=<shared-secret>
JONAH_URL=http://srv-captain--jonah:8000
POLY_API_KEY=<polymarket-key>
POLY_SECRET=<polymarket-secret>
POLY_PASSPHRASE=<polymarket-passphrase>
POLY_PRIVATE_KEY=<wallet-private-key>
POLY_ADDRESS=<wallet-address>
JWT_SECRET=<jwt-secret>
MARTY_ORIGIN=https://marty.wozark.com
DRY_MODE=false
SHADOW_MODE=false
PORT=3000
```

## 8. Marty

### Papel

Marty e o dashboard da operacao. Ele le Wendy por REST e WebSocket, mostra
estado e permite operacoes administrativas/manuais autenticadas.

### Stack

- Next.js 16 App Router.
- React 19.
- TypeScript strict.
- Recharts para graficos.
- Zustand para auth e estado de estacoes.
- WebSocket nativo.
- Static export servido por nginx.
- Tema Everforest dark.
- Fonte Manrope.

### Paginas

| Path | Conteudo |
| --- | --- |
| `/login` | Login JWT |
| `/` | Portfolio, cards de estacoes e estado geral |
| `/station/[icao]` | Detalhe de estacao, grafico, METAR, posicoes, logs |
| `/logs` | Logs com filtros |
| `/decisions` | Historico de decisoes BUY/SELL/ROTATE/SKIP |
| `/jonah` | Metricas e aprendizado Jonah |
| `/settings` | Config de trading |
| `/spread` | Tracker spread shadow |
| `/spread/skipped` | Razoes de skip |
| `/spread/stations` | Rollup por estacao |

### Padroes de UI

- Texto de UI em ingles.
- Comunicacao de projeto em portugues.
- BRT em toda exibicao de tempo.
- Excecao: um chip de horario local no breadcrumb da estacao.
- `age` e calculado por `Date.now() - validUtc`.
- `capturedAt` e diagnostico de ingest, nao base para idade.
- Cidade vem antes de ICAO.
- WebSocket e primario; polling de 60s e safety net.
- `refreshTick` no Zustand invalida fetches quando eventos chegam.
- Evitar acesso direto a banco.

### Tema

```text
bg        #272E33
surface   #2E383C
border    #374145
text      #D3C6AA
secondary #9DA9A0
dim       #7A8478
green     #A7C080
red       #E67E80
yellow    #DBBC7F
blue      #7FBBB3
purple    #D699B6
aqua      #83C092
```

Layout:

- Container max-width 1400px.
- Padding lateral 16px.
- Station grid responsivo 5 -> 3 -> 2 -> 1 colunas.
- Portfolio grid 4 -> 2 colunas.
- Settings com largura legivel de cerca de 820px.

### Comandos

```bash
npm install
npm run dev
npm run build
npm run start
npm run lint
npm run lint:fix
npm run format
npm run format:check
```

### Variaveis de ambiente

```env
NEXT_PUBLIC_WENDY_URL=https://wendy.wozark.com
NEXT_PUBLIC_WENDY_WS_URL=wss://wendy.wozark.com/ws
```

## 9. Jonah

### Papel

Jonah e o analista de previsao e aprendizado. Ele ingere METAR/Synoptic e PWS,
mantem buffers por estacao, roda ensemble, chama GPT-5 para decisao final,
publica prediction advisory e aprende com outcomes.

### Estado atual

Jonah esta em learning-only:

```text
TRIGGER_ENABLED = False
```

Com isso:

- `/prediction` continua ativo.
- `/signal` continua ativo.
- Ensemble e GPT continuam rodando.
- Learning e Qdrant continuam ativos.
- `/trigger` nao deve executar trade.
- `trigger_history` tende a ficar vazio ou historico.

### Pipeline

```text
Ruth /signal
  -> salvar METAR/PWS
  -> atualizar buffers
  -> agendar ou rodar ciclo
  -> LightGBM
  -> Chronos
  -> Open-Meteo
  -> RAG/Qdrant
  -> weighted ensemble
  -> GPT-5 final decision
  -> Wendy /prediction
  -> nightly learning
  -> Postgres Jonah + Qdrant
```

### Pesos atuais documentados

| Fonte | Peso | Observacao |
| --- | ---: | --- |
| Open-Meteo | 0.45 | Melhor base empirica recente |
| Chronos | 0.30 | Serie temporal balanceada |
| LightGBM | 0.20 | Historicamente over-estima |
| RAG | 0.05 | Demovido por divergencias grandes |

GPT-5 nao faz parte da media ponderada. Ele recebe o contexto e decide o bucket
final. Se GPT-5 falhar, fallback pode ser Claude; se tambem falhar, ensemble
bruto e fallback operacional.

### Scheduler

| Job | Frequencia | Uso |
| --- | --- | --- |
| `station_check` | 5 min | Detecta dawn/local cycle |
| Timer por METAR | 55 min apos chegada | Ciclo completo por estacao |
| Pre-METAR | Cerca de 5 min antes do METAR esperado | PWS gap e slope |
| `_save_snapshots` | 2 min | Persistencia de buffer |
| `_hourly_cycle` | xx:48 UTC | Tick horario |
| `learning_job` | `LEARNING_HOUR_UTC`, default 10 UTC | Resolve outcomes |
| `overnight_scan` | 08:00 UTC | Scanner direcional |

### Endpoints

| Metodo | Path | Uso |
| --- | --- | --- |
| GET | `/health` | Health, mode e accuracy |
| POST | `/signal` | Ingestao Ruth |
| GET | `/predictions` | Predicoes atuais |
| GET | `/predictions/{station}` | Predicao por estacao |
| POST | `/predictions/refresh` | Refresh manual geral |
| POST | `/predictions/refresh/{station}` | Refresh manual de estacao |
| POST | `/predict/{station}` | Predicao manual |
| GET | `/pre-metar` | Predicoes pre-METAR |
| GET | `/status` | Status interno |
| GET | `/logs` | Buffer de logs |
| GET | `/learning/metrics` | Accuracy e metricas |
| GET | `/learning/debug` | Diagnostico de resolucao |
| POST | `/rag/backfill` | Backfill legado |
| POST | `/admin/learning` | Learning manual |
| POST | `/admin/rag-backfill` | Backfill RAG |
| POST | `/admin/rag-rebuild` | Rebuild completo RAG |

### Tabelas Jonah

| Tabela | Uso |
| --- | --- |
| `metar_readings` | Observacoes METAR/Synoptic |
| `pws_readings` | Leituras PWS |
| `day_sessions` | Sessao diaria por estacao |
| `session_updates` | Evolucao da predicao |
| `learning_outcomes` | Resultado resolvido e comparacoes |
| `trigger_history` | Historico de trigger, dormente no modo atual |
| `buffer_snapshots` | Snapshots de buffer |

### Qdrant

- Colecao principal: `weather_days_v5`.
- Vetores representam dias/condicoes similares.
- Usado pelo RAG do Jonah.
- Rebuild historico combina dados historicos e outcomes recentes.

### Comandos

```bash
pip install -r requirements.txt
uvicorn src.main:app --host 0.0.0.0 --port 8000
pytest tests/
ruff check src tests
ruff check --fix src tests
ruff format src tests
```

### Variaveis de ambiente

```env
OPENAI_API_KEY=<openai-key>
GPT_MODEL=gpt-5
ANTHROPIC_API_KEY=<anthropic-key>
CLAUDE_FALLBACK_MODEL=claude-sonnet-4-6
JONAH_DATABASE_URL=postgresql://...@srv-captain--jonah-db:5432/jonah_prod
DATABASE_URL=postgresql://...@srv-captain--wbot-db:5432/wbot_prod
RUTH_SECRET=<shared-secret>
WENDY_URL=http://srv-captain--wendy:3000
QDRANT_HOST=srv-captain--qdrant
QDRANT_PORT=6333
WEIGHT_LGBM=0.20
WEIGHT_CHRONOS=0.30
WEIGHT_OPENMETEO=0.45
WEIGHT_RAG=0.05
LEARNING_HOUR_UTC=10
NWS_TIMEOUT=15
NOAA_CDO_TOKEN=<noaa-token>
PORT=8000
```

### Reativacao futura de trading por Jonah

Antes de reativar:

1. Medir accuracy por estacao em 30 dias.
2. Comparar Jonah contra market favorite por estacao.
3. Confirmar edge liquido depois de slippage e fill risk.
4. Definir gate por estacao, nao global.
5. Atualizar Wendy e Jonah no mesmo ciclo.
6. Observar em paper antes de execucao real.

Sem essas etapas, Jonah deve continuar advisory.

## 10. Polymarket, Wallet e Endpoints Externos

### Papel da Polymarket no sistema

Wendy usa a Polymarket em duas camadas diferentes:

1. Gamma API para descobrir eventos, mercados, labels de buckets e token IDs.
2. CLOB API/SDK para book, fee, tick size, assinatura e envio de ordens.

Jonah tambem consulta precos de mercado para contexto de previsao, mas nao
executa ordens no modo atual. Marty nunca fala direto com Polymarket; Marty fala
com Wendy.

### Endpoints externos usados

| API | Endpoint | Chamador | Uso |
| --- | --- | --- | --- |
| Gamma | `https://gamma-api.polymarket.com/events?slug=<slug>` | Wendy | Descobrir evento diario de temperatura, mercados e token IDs |
| CLOB | `https://clob.polymarket.com/book?token_id=<token>` | Wendy | Book snapshot, best bid/ask, liquidity, spread, tick size |
| CLOB | `https://clob.polymarket.com/price?token_id=<token>&side=<side>` | Wendy | Preco de mercado auxiliar |
| CLOB | `https://clob.polymarket.com/midpoint?token_id=<token>` | Wendy | Midpoint auxiliar |
| CLOB | `https://clob.polymarket.com/spread?token_id=<token>` | Wendy | Spread auxiliar |
| CLOB | `https://clob.polymarket.com/fee-rate?token_id=<token>` | Wendy | Fee rate em basis points |
| CLOB | `https://clob.polymarket.com/tick-size?token_id=<token>` | Wendy | Incremento minimo de preco |
| CLOB | `https://clob.polymarket.com/last-trades-prices?token_ids=<ids>` | Wendy | Ultimos trades em batch |
| CLOB SDK | `createAndPostMarketOrder` | Wendy | BUY/SELL FOK |
| CLOB SDK | `createOrder` + `postOrder` | Wendy | GTC fallback/limit order |
| CLOB SDK | `getOrder` | Wendy | Verificacao de fill |
| CLOB SDK | `cancelOrders` | Wendy | Cancelar ordem aceita mas nao preenchida |

### Slug dos mercados

Wendy constroi o slug diario da Gamma assim:

```text
highest-temperature-in-<citySlug>-on-<month-name>-<day>-<year>
```

Exemplo conceitual:

```text
highest-temperature-in-austin-on-april-8-2026
```

O `citySlug` vem da configuracao de estacoes. A data usada e a data local da
estacao, nao BRT e nao necessariamente UTC.

### Descoberta de token IDs

Fluxo de descoberta:

```text
station + localDate
  -> montar slug Gamma
  -> GET /events?slug=...
  -> ler event.markets[]
  -> para cada market:
       label = groupItemTitle
       threshold = groupItemThreshold
       conditionId = conditionId
       yesTokenId = clobTokenIds[0]
       noTokenId = clobTokenIds[1]
       yesPrice/noPrice = outcomePrices
  -> ordenar buckets por threshold
```

Wendy usa o `yesTokenId` para trading real. O caminho BUY NO/harvest foi
removido e nao deve ser recriado sem decisao explicita.

### Payload cache

Wendy mantem cache de payload estatico por `station -> bucketLabel`:

```text
tokenId
tickSize
negRisk
feeRateBps
```

Esse cache recarrega aproximadamente a cada 30 minutos para capturar mercados
novos e evitar token IDs obsoletos de dias anteriores.

No momento do trigger, Wendy chama `payloadCache.fire(station, bucket)`:

```text
static payload
  + fresh book snapshot
  -> bestAsk
  -> bestBid
  -> spread
  -> bidVolume
  -> askVolume
  -> hasLiquidity
```

Essa e a chamada de mercado que importa no hot path. O restante deve estar
pre-carregado quando possivel.

### Wallet e autenticacao CLOB

Wendy cria um singleton `ClobClient` com:

```text
HOST = https://clob.polymarket.com
CHAIN_ID = 137
wallet = ethers.Wallet(POLY_PRIVATE_KEY)
credentials = POLY_API_KEY + POLY_SECRET + POLY_PASSPHRASE
signatureType = 2
funder/address = POLY_ADDRESS, quando definido
```

Variaveis necessarias:

```env
POLY_PRIVATE_KEY=<private-key-da-wallet>
POLY_API_KEY=<clob-api-key>
POLY_SECRET=<clob-api-secret>
POLY_PASSPHRASE=<clob-api-passphrase>
POLY_ADDRESS=<proxy/funder-address>
```

Notas operacionais:

- A wallet e Polygon (`CHAIN_ID=137`).
- A private key assina ordens via SDK.
- As credenciais `POLY_API_*` autenticam no CLOB.
- `POLY_ADDRESS` identifica a proxy/funder wallet quando aplicavel.
- O codigo usa `signatureType = 2`, comentado como proxy wallet no SDK.
- Nao commitar valores reais dessas variaveis em docs ou codigo.

### Pre-requisitos da wallet

Antes de ligar trading real:

1. A wallet deve existir e controlar a private key configurada.
2. A proxy/funder wallet esperada pela Polymarket deve estar correta.
3. A conta deve ter USDC/collateral disponivel para ordens.
4. Permissoes/allowances exigidas pela Polymarket devem estar prontas.
5. Credenciais CLOB devem corresponder a wallet/proxy configurada.
6. `DRY_MODE` deve estar `false` apenas quando a operacao real for desejada.
7. `TRADING_ENABLED` e `METAR_TRADING_ENABLED` devem estar coerentes no
   `app_config`.

Se qualquer parte desse fluxo estiver errada, Wendy pode conseguir ler mercado
mas falhar ao assinar/postar ordem.

### BUY real

Fluxo de BUY:

```text
signal cruza bucket
  -> payloadCache.fire()
  -> guards
  -> escolher amount e price
  -> placeBuyOrder(client, tokenId, price, dollarAmount, opts)
  -> createAndPostMarketOrder(..., Side.BUY, OrderType.FOK)
  -> retry ate 3 vezes, subindo +$0.01 por tentativa
  -> cap de preco de retry em 0.74
  -> verificar resposta rapida
  -> se ambiguo, poll getOrder()
  -> exigir size_matched > 0
  -> salvar trade fire-and-forget
  -> broadcast trade_executed e position_update
```

Regras importantes:

- Valor minimo de BUY e `$1`.
- FOK nao preenchido deve ser tratado como falha.
- Ordem aceita sem fill e cancelada.
- `success: true` nao e suficiente.
- `size_matched > 0` e a evidencia operacional de fill.

### SELL real

Fluxo de SELL:

```text
sell/rotate/monitor
  -> placeSellOrder(client, tokenId, shares, opts)
  -> floor shares para 2 casas
  -> createAndPostMarketOrder(..., Side.SELL, OrderType.FOK)
  -> price = 0.01
  -> verificar resposta rapida
  -> se ambiguo, poll getOrder()
  -> exigir size_matched > 0
  -> salvar trade fire-and-forget
  -> broadcast trade_executed e position_update
```

Regras importantes:

- Menos de `0.01` shares nao vende.
- SELL tambem precisa verificacao por `size_matched`.
- SELL falho nao deve ser mascarado como sucesso.

### GTC fallback / limit order

Wendy tem helper para ordem limitada:

```text
createOrder(...)
postOrder(..., OrderType.GTC)
```

Uso esperado:

- fallback quando FOK nao resolve.
- cenarios onde manter ordem viva e aceitavel.

Restricao:

- GTC aumenta risco operacional porque ordem pode ficar aberta. Deve ser usado
  apenas nos caminhos ja previstos pelo trading engine.

### DRY_MODE

`DRY_MODE=true` desliga envio real ao CLOB:

- BUY retorna order id `dry-*` e shares simuladas.
- SELL retorna order id `dry-*` e shares vendidas simuladas.
- Saldo default documentado no codigo: `100`.
- Trades salvos carregam `dryRun=true`.

DRY mode e util para smoke test de fluxo sem wallet real, mas nao valida
assinatura, allowance, saldo, fill ou comportamento real do book.

### Market data vs execution data

Separar estes conceitos:

| Dado | Origem | Uso |
| --- | --- | --- |
| `yesPrice/noPrice` | Gamma event | Contexto e fallback visual |
| `bestAsk/bestBid` | CLOB book | Entrada, guards e spread |
| `tickSize` | CLOB book ou `/tick-size` | Parametro de ordem |
| `negRisk` | CLOB book | Parametro de ordem |
| `feeRateBps` | CLOB `/fee-rate` | Parametro de ordem |
| `size_matched` | CLOB `getOrder` | Verdade de fill |

Para trading, book e fill vencem precos agregados.

### Erros comuns

- Token ID de ontem: resolver via reload do payload cache.
- Slug do dia errado: checar timezone local da estacao.
- Book sem asks: nao ha entrada compravel.
- Book sem bids: pode bloquear liquidez/saida.
- API key errada: leitura publica pode funcionar, ordem falha.
- Private key errada: assinatura falha.
- `POLY_ADDRESS` errado: assinatura/autorizacao pode falhar mesmo com private
  key valida.
- Allowance/saldo insuficiente: ordem falha no CLOB.
- Ordem `success: true` com `size_matched=0`: tratar como phantom e cancelar.

### Endpoints internos relacionados a Polymarket

| Endpoint Wendy | Uso |
| --- | --- |
| `GET /positions` | Lista posicoes CLOB e PnL |
| `GET /balance` | Saldo e gasto diario |
| `POST /buy` | Ordem manual BUY |
| `POST /sell` | Ordem manual SELL |
| `GET /analytics/entries` | Analise de entradas |
| `GET /analytics/operations` | Guards e decisoes |
| `GET /ops/pnl` | PnL operacional |
| `GET /spread/*` | Simulador spread com dados Polymarket |
| `POST /spread/snapshot-now` | Arquivar trades Polymarket |
| `POST /spread/live-prices` | Consultar precos live por token |

Esses endpoints sao consumidos por Marty com JWT. Eles nao devem expor secrets.

## 11. Bancos e Schema

### Wendy Postgres

Database operacional: `wbot_prod`.

Tabelas:

| Tabela | Uso |
| --- | --- |
| `metar_observations` | Observacoes recebidas de Ruth |
| `pws_observations` | Legacy |
| `trades` | Ordens e execucoes |
| `logs` | Logs operacionais |
| `app_config` | Config mutavel de trading |
| `jonah_triggers` | Historico/analytics de predicoes/trigger legado |
| `auth_sessions` | Sessoes JWT |
| `spread_shadow_trades` | Legs do spread shadow |
| `polymarket_market_trades` | Arquivo bruto de trades Polymarket |

Campos importantes de `metar_observations`:

```text
station
temp_c
dewpoint_c
humidity_pct
wind_deg
wind_kt
gust_kt
visibility_m
cloud_layers
pressure_hpa
max_temp_c_6h
min_temp_c_6h
sea_level_pressure_hpa
ceiling_ft
wx_string
auto_station
metar_type
metar_raw
source
valid_utc
captured_at
trace_id
temp_precise
created_at
```

Campos importantes de `trades`:

```text
trace_id
station
action
side
bucket
token_id
amount
shares
price
order_id
fill_status
signal_type
market_snapshot
dry_run
created_at
```

Config importante em `app_config`:

```text
TRADING_ENABLED
METAR_TRADING_ENABLED
TRADING_MAX_SIZE
TRADING_MAX_DAILY_LOSS
ENABLED_STATIONS
AUTH_PASSWORD
AI_MIN_EDGE
AI_RELIABILITY_FLOOR
```

### Jonah Postgres

Database de aprendizado: `jonah_prod`.

Tabelas:

| Tabela | Uso |
| --- | --- |
| `metar_readings` | Densidade de observacoes METAR/Synoptic |
| `pws_readings` | Densidade PWS |
| `day_sessions` | Estado diario por estacao |
| `session_updates` | Timeline de updates |
| `learning_outcomes` | Resultado real e metricas |
| `trigger_history` | Historico dormente |
| `buffer_snapshots` | Recovery de buffer |

### Convencoes de nomes

| Camada | Convencao | Exemplo |
| --- | --- | --- |
| Ruth JSON | camelCase | `tempC`, `metarRaw`, `capturedAt` |
| Wendy TypeScript | camelCase | `runningMaxC`, `metarTradingEnabled` |
| Wendy DB | snake_case | `temp_c`, `metar_raw`, `captured_at` |
| Jonah Python | snake_case interno | `valid_utc`, `market_snapshot` |
| Jonah payload input | aceita camelCase | `body.get("tempC")` |

## 12. Desenvolvimento Local

Cada servico desenvolve isoladamente:

```bash
cd wbot-ruth
cargo run

cd wbot-wendy
npm install
npm run dev

cd wbot-marty
npm install
npm run dev

cd wbot-jonah
pip install -r requirements.txt
uvicorn src.main:app --host 0.0.0.0 --port 8000
```

Build/test antes de push:

| Servico | Build | Test | Lint/format |
| --- | --- | --- | --- |
| Ruth | `cargo build --release` | `cargo test` | `cargo fmt`, `cargo clippy` |
| Wendy | `npm run build` | `npm test` | `npm run lint`, `npm run format` |
| Marty | `npm run build` | build e smoke visual | `npm run lint`, `npm run format` |
| Jonah | import/uvicorn smoke | `pytest tests/` | `ruff check`, `ruff format` |

## 13. Deploy

Deploy e feito por Git push para o branch monitorado pelo CapRover. Cada servico
e independente e possui seu proprio deploy.

Regras:

- Commit antes de push.
- Build/test local antes de push.
- Se alterar mais de um servico, validar contratos entre eles.
- Se alterar Wendy endpoints, validar Ruth, Marty e Jonah.
- Se alterar payload Ruth, validar Wendy e Jonah.
- Se alterar eventos WS, validar Marty.
- Nao usar UI do CapRover como substituto de Git push.

Servicos em producao:

| Servico | URL externa |
| --- | --- |
| Wendy | `https://wendy.wozark.com` |
| Marty | `https://marty.wozark.com` |
| CapRover | `https://captain.wozark.com` |

Ruth e Jonah sao internos.

## 14. Padroes de Codigo

### Geral

- Comunicacao do projeto em portugues.
- Codigo, nomes de variaveis, funcoes e commits em ingles.
- Commits seguem Conventional Commits.
- Nao deixar dead code "para futuro".
- Nao adicionar fallback/heuristica de trading sem decisao explicita.
- Comentarios devem explicar contexto nao obvio, nao narrar codigo trivial.

### Rust/Ruth

- Rust 2021.
- Axum 0.8 e Tokio.
- Serde camelCase para payloads.
- `tracing` para logs.
- Evitar `unwrap()` em hot path.
- `rustfmt` e `clippy`.

### TypeScript/Wendy

- TypeScript strict.
- ESM.
- Fastify 5.
- Zod em input.
- Pino structured logging.
- Drizzle para schema/query.
- Sem semicolons.
- Single quotes.
- 100 colunas.

### TypeScript/Marty

- React 19.
- Next.js App Router.
- TypeScript strict.
- Sem semicolons.
- Single quotes.
- 100 colunas.
- Inline styles e tokens Everforest dominam.
- Tailwind existe, mas nao deve virar mistura sem necessidade.

### Python/Jonah

- Python 3.12.
- FastAPI.
- Ruff.
- 100 colunas.
- Double quotes.
- DB writes defensivos em ingestao.
- Erro transiente de INSERT nao deve derrubar `/signal`.

## 15. Aprendizados Historicos

### Synoptic-first

O maior erro historico foi tratar METAR como texto horario em vez de sinal
fresco. O modelo correto:

- Synoptic expoe `air_temp` com cadencia mais densa.
- `metar_set_1` pode estar atrasado ou representar o boletim horario.
- Trade deve reagir a `air_temp`/`obs_time`.
- Texto METAR serve para enriquecer campos auxiliares.
- Bots que esperam TGFTP/METAR horario podem ficar minutos atras.

### Jonah learning-only

Jonah ficou learning-only porque resultados de aprendizado mostraram performance
sub-baseline em varias estacoes. Um veto ruim pode bloquear trades bons. Sem
prova por estacao de que Jonah bate mercado, ele deve continuar advisory.

### FOK verification

`success: true` no CLOB nao e prova de fill. Sempre verificar size matched. Essa
regra existe por experiencia com fills fantasmas e estados inconsistentes.

### Running max

`runningMaxC` nao desce durante o dia. Ele representa a maxima observada. Bugs em
maxima derivada ou rolling max falso ja causaram phantom max e decisoes ruins.

### Rotate

Rotacao segura compra novo primeiro. Vender antigo antes do novo fill abre risco
de ficar sem exposicao correta.

### BUY NO removido

BUY NO/harvest parecia recuperacao, mas adicionava exposicao e complexidade sem
edge comprovado. A regra atual e SELL do antigo, nao BUY NO.

### TGFTP

TGFTP e arquivo estatico de texto da NOAA. Nao tratar como API com rate limit.
Pode ter erro transiente de rede, mas nao precisa de arquitetura pesada de
proteccao.

### Helsinki

Infra em Helsinki ja resolveu a parte principal de latencia de rede para
Polymarket. Otimizacoes relevantes agora estao em dado, decisao, cache, fill,
backtest e modelo.

### Documentacao antiga

Docs antigos ja ficaram errados sobre `/trigger`, PWS e modo Jonah. Por isso a
documentacao foi consolidada em documento unico. Se algo mudar, atualizar este
documento no mesmo ciclo da mudanca.

## 16. Checklist para Mudancas

Antes de mudar:

- Identificar quais servicos sao afetados.
- Confirmar comportamento no codigo.
- Listar contratos tocados.
- Verificar se ha risco financeiro.
- Separar hipotese de fato medido.

Ao mudar Ruth:

- Preservar Synoptic fresh sensor como fonte de verdade.
- Garantir PWS somente para Jonah.
- Validar dedup e timestamps.
- Rodar `cargo test`.

Ao mudar Wendy:

- Ler o fluxo completo da funcao de trading afetada.
- Verificar guard order.
- Verificar lock e fill verification.
- Nao reintroduzir BUY NO.
- Rodar build e testes.

Ao mudar Marty:

- Manter BRT.
- Manter acesso apenas via Wendy.
- Testar telas afetadas em desktop/mobile quando houver UI.
- Garantir que texto nao estoure containers.

Ao mudar Jonah:

- Confirmar learning-only.
- Nao declarar edge sem metrics.
- Validar DB writes defensivos.
- Rodar pytest/ruff conforme escopo.

Antes de push:

- `git status --short`.
- Build/test do servico afetado.
- Commit com mensagem convencional.
- Push para branch principal do repo correto.

## 17. Glossario

| Termo | Definicao |
| --- | --- |
| Bucket | Faixa de temperatura do mercado Polymarket. |
| CLOB | Central Limit Order Book da Polymarket. |
| FOK | Fill-or-Kill order. |
| GTC | Good-til-cancelled order. |
| METAR | Observacao meteorologica aeroportuaria; no sistema tambem nomeia o tipo de sinal Ruth. |
| PWS | Personal Weather Station, usada como contexto para Jonah. |
| RAG | Retrieval-augmented generation via Qdrant similar-days. |
| T-group | Grupo preciso de temperatura no METAR horario. |
| `runningMaxC` | Maxima diaria observada em Celsius. |
| `validUtc` | Timestamp real da observacao. |
| `capturedAt` | Momento em que Ruth capturou/publicou o dado. |

## 18. Politica de Documentacao

Esta pasta deve conter a documentacao canonica atual. Documentos antigos,
duplicados ou conflitantes devem ser removidos em vez de mantidos como memoria
paralela. Historico de decisoes importantes deve entrar neste documento como
aprendizado consolidado.
