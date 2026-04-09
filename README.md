# Wozark Workspace

Workspace principal do sistema de weather trading da Wozark. Este repositorio agrega os subprojetos, a documentacao operacional e os scripts de suporte.

## Estrutura

| Projeto | Diretorio | Stack | Papel |
| --- | --- | --- | --- |
| Workspace | `.` | docs + scripts | Operacao e referencia |
| Ruth | `wbot-ruth/` | Rust, Tokio | Captura METAR e PWS |
| Wendy | `wbot-wendy/` | TypeScript, Fastify, Drizzle | Execucao, estado, API e WebSocket |
| Marty | `wbot-marty/` | Next.js 16, React 19 | Dashboard operacional |
| Jonah | `wbot-jonah/` | Python 3.12, FastAPI, LightGBM, Chronos, Qdrant, OpenAI | Predicao, learning e RAG |

## Arquitetura atual

```text
Ruth  -- POST /signal ----------> Wendy -- REST/WS ----------> Marty
  \                                ^
   \-- POST /signal (copia) ----> Jonah -- /prediction -----> Wendy
                                      \-- /trigger ---------> Wendy
```

- Ruth consulta as estacoes ativas em Wendy via `GET /stations/config`.
- Wendy concentra configuracao, guards, trades, logs, analytics e broadcast.
- Marty fala apenas com Wendy.
- Jonah roda o ensemble, registra advisory em `/prediction` e dispara execucao em `/trigger`.

## Modo operacional auditado em 2026-04-08

- Jonah voltou a ser o caminho ativo de entrada pre-METAR por default.
- o trigger AI deixou de ser um toggle operacional; Wendy sempre considera `/trigger` elegivel e deixa a decisao final para os guards de runtime.
- METAR nao faz mais entrada tardia nova:
  - se confirmar o bucket comprado por Jonah, Wendy mantem a posicao;
  - se divergir, Wendy rotaciona para o bucket oficial;
  - se nao existir posicao pre-METAR, o METAR fica apenas como confirmacao/log.
- PWS continua alimentando analytics, buffers e contexto, mas nao dispara ordem sozinho.
- A base operacional foi limpa para manter dados a partir de `2026-04-01`.

## Qualidade atual de learning e RAG

- `learning_outcomes` em `jonah_prod` hoje cobrem `2026-04-01` ate `2026-04-07` e somam `70` rows.
- Isso ja e suficiente para filtros simples por `station + local_hour`, mas ainda nao para sizing agressivo fino.
- O bug que impedia salvar `market_snapshot` em `session_updates` foi corrigido em `2026-04-08`.
- Consequencia:
  - historico antigo de `beat_market_rate` nao e confiavel;
  - os novos dias, a partir dessa correcao, passam a alimentar esse eixo corretamente.
- O Qdrant real em Jonah usa a collection `weather_days_v5` com vetor de `12` dimensoes.
- Em `2026-04-08`, a collection antiga foi removida e a `weather_days_v5` foi rebuildada com duas camadas:
  - `18,604` dias historicos de `data/historical/all_stations.csv`
  - `70` dias recentes ricos de `learning_outcomes`
- Estado final da collection: `18,674` pontos.
- A qualidade do RAG melhorou porque a memoria longa foi preservada e a memoria recente rica foi mantida por cima, mas o bloco de `beat-market` ainda depende de acumular mais dias novos com `market_snapshot` corrigido.

## Documentos principais

- `docs/system-overview-2026-04-08.md`: arquitetura, fluxos, thresholds, riscos de negocio e estado operacional real.
- `docs/database-schema.md`: bancos, contratos, retencao e Qdrant.
- `scripts/health-check.sh`: verificacoes externas.
- `scripts/health-check-internal.sh`: verificacoes internas no VPS.

## Setup rapido

```bash
mkdir -p ~/personal/wozark && cd ~/personal/wozark

git clone git@github.com:Ths33/wozark.git .
git clone git@github.com:Ths33/ruth.git wbot-ruth
git clone git@github.com:Ths33/wendy.git wbot-wendy
git clone git@github.com:Ths33/marty.git wbot-marty
git clone git@github.com:Ths33/jonah.git wbot-jonah
```

### Ruth

```bash
cd wbot-ruth
cp .env.example .env
cargo run
```

### Wendy

```bash
cd wbot-wendy
cp .env.example .env
npm install
npm run dev
```

### Marty

```bash
cd wbot-marty
cp .env.example .env
npm install
npm run dev
```

### Jonah

```bash
cd wbot-jonah
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000
```

## Variaveis de ambiente

Cada projeto tem o proprio `.env.example`. Os pontos operacionais mais importantes hoje sao:

### Ruth

- `WENDY_URL`
- `RUTH_SECRET`
- `WU_API_KEY`
- `NOAA_POLL_MS`
- `PWS_POLL_MS`
- `JONAH_ENABLED`
- `JONAH_URL`

### Wendy

- `DATABASE_URL`
- `RUTH_SECRET`
- `JWT_SECRET`
- `AUTH_PASSWORD`
- `POLY_*`
- `MARTY_ORIGIN`
- `JONAH_URL`
- `QDRANT_URL`

Chaves operacionais em `app_config`:

- `TRADING_ENABLED`
- `TRADING_MAX_SIZE`
- `TRADING_MAX_DAILY_LOSS`
- `ENABLED_STATIONS`
- `AI_MIN_EDGE`
- `AI_RELIABILITY_FLOOR`

### Marty

- `NEXT_PUBLIC_WENDY_URL`
- `NEXT_PUBLIC_WENDY_WS_URL`

### Jonah

- `WENDY_URL`
- `RUTH_SECRET`
- `OPENAI_API_KEY`
- `GPT_MODEL`
- `DATABASE_URL`
- `JONAH_DATABASE_URL`
- `QDRANT_HOST`
- `QDRANT_PORT`

## Producao

| Servico | URL publica | Host interno |
| --- | --- | --- |
| Wendy | `https://wendy.wozark.com` | `srv-captain--wendy:3000` |
| Marty | `https://marty.wozark.com` | export estatico via nginx |
| Ruth | interno | `srv-captain--ruth:8080` |
| Jonah | interno | `srv-captain--jonah:8000` |
| Wendy DB | interno + porta externa | `srv-captain--wdb:5432/15432` |
| Jonah DB | interno + porta externa | `srv-captain--jonah-db:5432/25432` |
| Qdrant | interno | `srv-captain--qdrant:6333` |

## Health checks

```bash
bash scripts/health-check.sh
ssh root@168.231.70.56 'bash -s' < scripts/health-check-internal.sh
```

## Estacoes ativas

`KSEA`, `KLAX`, `KSFO`, `KDAL`, `KAUS`, `KHOU`, `KORD`, `KLGA`, `KMIA`, `KATL`
