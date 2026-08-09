# Wozark — Catalogo de Projeto e Aprendizados

Atualizado em 2026-08-09 a partir da varredura local do workspace.

Este documento e o indice ponta a ponta do projeto. Ele consolida arquitetura,
pastas, fontes de verdade, aprendizados operacionais e pontos onde a
documentacao antiga conflita com o comportamento atual.

## 1. Resumo executivo

Wozark e um sistema de auto-trading em Polymarket para mercados de temperatura
maxima diaria. O sistema e dividido em quatro servicos independentes:

| Servico | Pasta | Stack | Papel |
| --- | --- | --- | --- |
| Ruth | `wbot-ruth/` | Rust, Axum, Tokio | Sensor meteorologico. Captura Synoptic/TGFTP/PWS e publica sinais. |
| Wendy | `wbot-wendy/` | TypeScript, Fastify 5, Drizzle, Postgres | Cerebro de trading. Calcula buckets, guards e executa CLOB. |
| Marty | `wbot-marty/` | Next.js 16, React 19, Recharts | Dashboard operacional em tempo real. |
| Jonah | `wbot-jonah/` | Python 3.12, FastAPI, LightGBM, Chronos, Qdrant, GPT-5 | Analista de previsao e aprendizado, atualmente learning-only. |

Fluxo atual de alto nivel:

```text
Synoptic /timeseries + TGFTP + PWS
  -> Ruth
  -> Wendy /signal              (METAR/Synoptic fresh sensor, trading)
  -> Jonah /signal              (METAR + PWS, learning)
  -> Jonah /prediction -> Wendy (advisory)
  -> Wendy REST/WS -> Marty     (dashboard)
```

Fonte de verdade atual:

- Comportamento ativo: codigo em `wbot-*/src`, depois `CLAUDE.md` mais recente.
- Contexto e decisoes: `.claude/memory/*.md`.
- Docs antigos em `docs/system-overview-2026-04-08.md` e alguns planos devem ser
  lidos como historico, nao como verdade operacional.

## 2. Estado atual mais importante

- Synoptic e a fonte primaria de edge. Ruth usa leituras frescas de sensor
  (`air_temp`, `obs_time`) expostas via `/timeseries`, nao a temperatura parseada
  do texto METAR horario.
- Wendy esta em modo de trading METAR/Synoptic puro: sinais de Ruth podem gerar
  BUY/ROTATE quando `runningMaxC` cruza bucket e os guards passam.
- Jonah esta em `LEARNING-ONLY`: `TRIGGER_ENABLED = False` em
  `wbot-jonah/src/proxy.py`. Ele envia `/prediction` advisory, mas nao dispara
  trades.
- Wendy removeu o caminho historico `/trigger` como caminho de execucao de trade
  de Jonah. Nao reintroduzir sem decisao explicita.
- PWS vai somente para Jonah. PWS nunca deve ser enviado para Wendy como trigger
  de trading.
- BUY NO / harvest foi removido por decisao de produto. Rotacao usa BUY novo
  primeiro e recuperacao via SELL do bucket antigo, nao BUY NO.
- Marty nunca acessa banco diretamente. Toda leitura/escrita passa por Wendy.
- Toda UI de tempo em Marty usa BRT, exceto um unico chip de horario local da
  estacao.

## 3. Mapa de pastas

| Caminho | Conteudo | Observacoes |
| --- | --- | --- |
| `README.md` | Visao geral atual do sistema | Bom ponto de entrada. |
| `CLAUDE.md` | Regras mestras, arquitetura e convencoes | Mais atual que alguns docs antigos. |
| `docs/` | Arquitetura, schema e este catalogo | `system-overview-2026-04-08.md` esta parcialmente obsoleto. |
| `.claude/memory/` | Aprendizados e correcoes historicas | Deve ser consultado antes de mudar comportamento sensivel. |
| `scripts/` | Health checks | Scripts auxiliares de operacao. |
| `backups/2026-05-06/` | Dumps e runbook de migracao | Backup operacional; estava nao rastreado na varredura. |
| `wbot-ruth/` | Sensor Rust | Sem banco e sem logica de negocio. |
| `wbot-wendy/` | Trading brain TypeScript | Modulo mais sensivel financeiramente. |
| `wbot-marty/` | Dashboard Next.js | Static export servido por nginx. |
| `wbot-jonah/` | Analista Python | Learning, RAG, modelos e backtests. |

## 4. Catalogo dos servicos

### Ruth (`wbot-ruth/`)

Papel: sensor puro.

Arquivos principais:

- `src/main.rs`: bootstrap Axum e tasks long-lived.
- `src/config.rs`: envs e lista de estacoes vinda de Wendy.
- `src/sender.rs`: POST para Wendy/Jonah, circuit breaker e retry buffer.
- `src/metar/synoptic.rs`: cliente Synoptic `/timeseries?recent=120`.
- `src/metar/poller.rs`: slot scheduler, TGFTP paralelo/fallback e hot-poll.
- `src/metar/parser.rs`: parsing do texto METAR para enriquecimento.
- `src/pws/poller.rs`: Weather Underground PWS para Jonah.

Aprendizados chave:

- Ruth nao decide trade, nao calcula bucket e nao escreve em banco.
- Slots principais: `:00, :05, ..., :50, :51, :53, :55`.
- Hot-poll `:50-:58` captura T-group preciso.
- Synoptic e primaria; TGFTP e fallback e tambem paralelo em `:51/:53`.
- `metar_raw` enriquece campos auxiliares, mas nao sobrescreve temp/timestamp
  frescos do Synoptic.

Comandos:

```bash
cargo build --release
cargo test
cargo fmt
cargo clippy
```

### Wendy (`wbot-wendy/`)

Papel: cerebro de trading e API operacional.

Arquivos principais:

- `src/server.ts`: registro de endpoints e bootstrap.
- `src/modules/signal/signal.route.ts`: entrada `POST /signal`.
- `src/modules/signal/signal.service.ts`: `runningMaxC`, bucket e fluxo de sinal.
- `src/modules/signal/trade-dispatch.ts`: guards e execucao.
- `src/modules/buy/`, `src/modules/sell/`, `src/modules/rotate/`: CLOB actions.
- `src/modules/monitor/`: sync, retry e auto-sell.
- `src/modules/spread/`: spread shadow trader D+2.
- `src/shared/guards.ts`: regras de bloqueio.
- `src/shared/db/schema.ts`: schema Drizzle.
- `src/shared/market/`, `src/shared/clob/`: Gamma/CLOB/cache/payload.

Aprendizados chave:

- `runningMaxC` e monotonicamente crescente no dia.
- Trade hot path evita await de escrita em DB quando possivel.
- Guards rodam antes de ordem: janela, resolucao, range de preco, border zone,
  daily loss, liquidez/book e lock.
- FOK precisa verificacao por `getOrder().size_matched`; `success: true` nao basta.
- ROTATE compra o bucket novo antes de vender o antigo.
- `metarTradingEnabled=false` bloqueia trade por sinal; `tradingEnabled=false` e
  kill switch absoluto.
- Spread trader e simulador/shadow separado do METAR trading.

Comandos:

```bash
npm install
npm run dev
npm run build
npm test
npm run lint
npm run format
```

### Marty (`wbot-marty/`)

Papel: dashboard real-time.

Arquivos principais:

- `app/page.tsx`: home operacional.
- `app/station/[icao]/StationClient.tsx`: detalhe por estacao.
- `app/logs/page.tsx`, `app/decisions/page.tsx`, `app/jonah/page.tsx`,
  `app/settings/page.tsx`: telas operacionais.
- `app/spread/`: tracker de spread shadow.
- `components/charts/`: graficos Recharts.
- `components/layout/WsProvider.tsx`: WebSocket e refresh.
- `lib/api.ts`: cliente REST para Wendy.
- `lib/ws.ts`: singleton WebSocket.
- `lib/stations.ts`: metadata, BRT helpers e nomes.
- `stores/stations.ts`: Zustand e `refreshTick`.

Aprendizados chave:

- Marty le Wendy via REST + WebSocket; nao toca DB.
- WS e primario; polling de 60s e safety net.
- `refreshTick` e o padrao de invalidacao global.
- UI text em ingles; comunicacao do projeto em portugues.
- Tema Everforest dark, Manrope, sem component library dominante.
- `age` usa `validUtc`, nao `capturedAt`.

Comandos:

```bash
npm install
npm run dev
npm run build
npm run lint
npm run format
```

### Jonah (`wbot-jonah/`)

Papel: analista de previsao e aprendizado.

Arquivos principais:

- `src/main.py`: FastAPI, scheduler, endpoints e lifecycle.
- `src/proxy.py`: push `/prediction` e gate `TRIGGER_ENABLED`.
- `src/predictor.py`: orquestracao da pipeline.
- `src/ensemble.py`: combinacao das fontes.
- `src/ml_model.py`: LightGBM.
- `src/chronos_fc.py`: Chronos-Bolt.
- `src/forecast.py`: Open-Meteo.
- `src/rag.py`, `src/rag_rebuild.py`: Qdrant e rebuild.
- `src/gpt.py`: GPT-5 e fallback Claude.
- `src/learning.py`: resolucao diaria e outcomes.
- `src/db.py` e arquivos `db_*`: persistencia.
- `backtest/`: simulacoes e relatorios.

Aprendizados chave:

- Modo atual e learning-only; nao explicar como executor ativo.
- Pipeline completa continua ativa: ingestao, buffers, ensemble, GPT, prediction,
  learning e Qdrant.
- Antes de reativar trade por Jonah, validar edge real em `/learning/metrics`.
- Pesos documentados mais recentes no `CLAUDE.md`: Open-Meteo 0.45, Chronos
  0.30, LightGBM 0.20, RAG 0.05.
- Docs mais antigos ainda citam RAG 0.25 e `/trigger` ativo; tratar como
  historico.

Comandos:

```bash
pip install -r requirements.txt
uvicorn src.main:app --host 0.0.0.0 --port 8000
pytest tests/
ruff check src tests
ruff format src tests
```

## 5. Fluxos criticos

### Signal hot path

```text
Ruth observa leitura fresca
  -> POST Wendy /signal
  -> Wendy valida Zod
  -> salva METAR fire-and-forget
  -> WS new_metar para Marty
  -> atualiza runningMaxC
  -> calcula bucket
  -> se bucket mudou e trading esta habilitado:
       guards
       BUY ou ROTATE
       broadcast trade_executed/trade_skipped
```

### Learning path

```text
Ruth -> Jonah /signal
  -> salva METAR/PWS
  -> atualiza buffers
  -> roda ciclos agendados
  -> ensemble + GPT-5
  -> /prediction para Wendy
  -> Wendy broadcast ai_prediction
  -> nightly learning resolve outcomes
  -> Postgres Jonah + Qdrant
```

### Dashboard path

```text
Browser Marty
  -> login JWT em Wendy
  -> REST para dados atuais
  -> WS para eventos
  -> refreshTick invalida telas
```

## 6. Dados e persistencia

Wendy (`wbot_prod`) guarda operacao:

- `metar_observations`
- `pws_observations` legacy
- `trades`
- `logs`
- `app_config`
- `jonah_triggers` historico/analitico
- `auth_sessions`
- `spread_shadow_trades`
- `polymarket_market_trades`

Jonah (`jonah_prod`) guarda aprendizado:

- `metar_readings`
- `pws_readings`
- `day_sessions`
- `session_updates`
- `learning_outcomes`
- `trigger_history`
- `buffer_snapshots`

Qdrant:

- Colecao principal documentada: `weather_days_v5`.
- Usada para RAG/similar-days do Jonah.

Regra de seguranca: credenciais e URLs sensiveis existem em referencias locais,
mas nao devem ser copiadas para documentos de onboarding.

## 7. Documentos existentes

| Documento | Status | Uso recomendado |
| --- | --- | --- |
| `README.md` | Atual | Entrada rapida do sistema. |
| `CLAUDE.md` | Atual | Regras mestras e convencoes operacionais. |
| `docs/architecture.md` | Parcialmente atual | Diagrama util, mas verificar detalhes em codigo. |
| `docs/database-schema.md` | Parcialmente historico | Bom mapa de tabelas; validar schema atual antes de migrar. |
| `docs/system-overview-2026-04-08.md` | Obsoleto em pontos criticos | Historico; cita `/trigger` ativo e deve ser reconciliado antes de uso. |
| `wbot-ruth/README.md` e `CLAUDE.md` | Atual | Fonte de arquitetura do sensor. |
| `wbot-wendy/README.md` e `CLAUDE.md` | Atual | Fonte de trading brain. |
| `wbot-marty/README.md` e `CLAUDE.md` | Atual | Fonte de UI/dashboard. |
| `wbot-jonah/README.md` e `CLAUDE.md` | Atual | Fonte de learning-only e pipeline. |
| `.claude/memory/*.md` | Critico | Decisoes, correcoes e preferencias do usuario/projeto. |
| `backups/2026-05-06/MIGRATION_RUNBOOK.md` | Operacional | Runbook de migracao/backup. |

## 8. Aprendizados consolidados

1. O edge do projeto nao e "parsear METAR mais rapido"; e usar leituras frescas
   do Synoptic antes do METAR horario confirmar.
2. Codigo vence documento. Docs ja ficaram desatualizados em fluxos de trigger,
   PWS e comportamento do Jonah.
3. Trading logic exige leitura completa do fluxo antes de editar. Mudancas pequenas
   em Wendy podem afetar Ruth, Marty e Jonah.
4. Jonah sem edge medido nao deve vetar nem executar trades. Learning-only nasceu
   porque a performance estava sub-baseline em varias estacoes.
5. Separar observacao de posicao evita reconciliacao ruim: `runningMaxC`/bucket
   observado nao devem ser confundidos com bucket em posicao.
6. Verificacao de fill e obrigatoria. CLOB pode responder sucesso sem fill util.
7. Fire-and-forget no hot path e decisao de latencia, nao descuido.
8. BRT e padrao de produto para UI; UTC e detalhe de log/DB.
9. Infra em Helsinki ja resolveu a parte de latencia de rede; o foco deve ser
   logica, dados, backtest e qualidade do modelo.
10. TGFTP e arquivo estatico sem rate limit relevante; nao over-engineerar
    protecoes especificas para ele.
11. BUY NO/harvest e uma decisao removida; nao reabrir sem nova decisao.
12. Deploy neste projeto significa `git push` para o repo/branch monitorado pelo
    CapRover, sempre apos build/test local do servico afetado.

## 9. Checklist para qualquer mudanca futura

- Consultar `.claude/memory/MEMORY.md` primeiro.
- Grepar chamadas em todos os quatro servicos quando mudar contrato HTTP,
  payload, header ou evento WS.
- Em Wendy, ler a funcao inteira antes de alterar guards, sizing, bucket,
  rotate, buy/sell ou CLOB.
- Em Ruth, preservar sensor-fresh source of truth.
- Em Jonah, confirmar `TRIGGER_ENABLED` antes de descrever execucao.
- Em Marty, manter BRT e acesso apenas via Wendy.
- Rodar build/test do servico alterado antes de push.
- Se a mudanca e heuristica, reportar como hipotese, com falhas possiveis e nivel
  de validacao.

## 10. Inventario rapido

- Servicos principais: 4.
- Arquivos fonte principais varridos em `src/app/components/lib/stores`: 161.
- Linguagens: Rust, TypeScript, Python, CSS.
- Bancos: Postgres Wendy, Postgres Jonah, Qdrant.
- Integracoes externas: Synoptic, TGFTP/NOAA, Weather Underground PWS,
  Polymarket Gamma/CLOB, Open-Meteo, NWS, OpenAI GPT-5, Claude fallback.
