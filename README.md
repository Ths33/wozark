# Wozark Workspace

Workspace principal do sistema de weather auto-trading da Wozark. Este repositorio nao contem a aplicacao em si; ele agrega os quatro subprojetos, documentacao operacional, logs de referencia e scripts de health check.

## Estrutura

| Projeto   | Diretorio     | Stack atual                                             | Papel                                |
| --------- | ------------- | ------------------------------------------------------- | ------------------------------------ |
| Workspace | `.`           | docs + scripts                                          | Orquestracao, referencias e operacao |
| Ruth      | `wbot-ruth/`  | Rust, Axum, Tokio                                       | Sensor de METAR e PWS                |
| Wendy     | `wbot-wendy/` | TypeScript, Fastify 5, Drizzle                          | Trading brain + API                  |
| Marty     | `wbot-marty/` | Next.js 16, React 19, Tailwind v4, Zustand              | Dashboard operacional                |
| Jonah     | `wbot-jonah/` | Python 3.12, FastAPI, LightGBM, Chronos, Qdrant, OpenAI | Predicao e sinais auxiliares         |

## Arquitetura

```text
Ruth  -- POST /signal ------> Wendy -- REST/WS ------> Marty
  \                           |                         ^
   \-- POST /signal -------> Jonah -- /prediction -----/
                              |-- /trigger -----------> Wendy
                              \-- /gpt-signal --------> Wendy
```

- Ruth busca a lista de estacoes em Wendy via `GET /stations/config`.
- Wendy e a fonte central de configuracao, execucao de trades, logs e estado operacional.
- Marty consome apenas a API/WebSocket da Wendy.
- Jonah roda o ensemble meteorologico e envia sinais consultivos ou gatilhos para Wendy.

Modo operacional atual auditado:

- execucao automatica habilitada apenas para sinais METAR
- Jonah continua gerando previsoes, learning/RAG e dados para dashboard
- triggers AI ficam em modo advisory por padrao via `AI_TRADING_ENABLED=false`

## O que existe neste repo

- `docs/database-schema.md`: contrato atual de bancos e payloads entre servicos.
- `docs/2026-03-23-v5-architecture-design.md`: documento historico da arquitetura V5.
- `docs/backlog-2026-03-28.md`: backlog tecnico consolidado.
- `scripts/health-check.sh`: verifica o que e acessivel externamente.
- `scripts/health-check-internal.sh`: verifica servicos internos quando executado no VPS.
- `logs/`: snapshots CSV usados para analise e referencia operacional.

## Setup do workspace

```bash
mkdir -p ~/personal/wozark && cd ~/personal/wozark

git clone git@github.com:Ths33/wozark.git .
git clone git@github.com:Ths33/ruth.git wbot-ruth
git clone git@github.com:Ths33/wendy.git wbot-wendy
git clone git@github.com:Ths33/marty.git wbot-marty
git clone git@github.com:Ths33/jonah.git wbot-jonah
```

## Setup rapido por projeto

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

Cada projeto tem um `.env.example` documentado. Abaixo o resumo completo.

### Ruth (Sensor)

| Variavel        | Obrigatorio | Descricao                                               |
| --------------- | ----------- | ------------------------------------------------------- |
| `WENDY_URL`     | Sim         | URL interna de Wendy (`http://srv-captain--wendy:3000`) |
| `RUTH_SECRET`   | Sim         | Segredo compartilhado (mesmo valor em Wendy/Jonah)      |
| `WU_API_KEY`    | Sim         | API key do Weather Underground para PWS                 |
| `NOAA_POLL_MS`  | Nao         | Intervalo rapido de polling METAR (default: 3000)       |
| `PWS_POLL_MS`   | Nao         | Intervalo de polling PWS (default: 300000 = 5min)       |
| `JONAH_ENABLED` | Nao         | Habilitar envio para Jonah (default: false)             |
| `JONAH_URL`     | Nao         | URL interna de Jonah                                    |
| `RUST_LOG`      | Nao         | Nivel de log (default: `wbot_ruth=info`)                |

### Wendy (Brain)

| Variavel           | Obrigatorio | Descricao                                |
| ------------------ | ----------- | ---------------------------------------- |
| `DATABASE_URL`     | Sim         | PostgreSQL connection string             |
| `RUTH_SECRET`      | Sim         | Segredo para auth service-to-service     |
| `JWT_SECRET`       | Sim         | Segredo para tokens JWT (Marty auth)     |
| `AUTH_PASSWORD`    | Sim         | Senha inicial do operador                |
| `POLY_API_KEY`     | Sim\*       | Polymarket CLOB API key                  |
| `POLY_SECRET`      | Sim\*       | Polymarket CLOB secret                   |
| `POLY_PASSPHRASE`  | Sim\*       | Polymarket CLOB passphrase               |
| `POLY_PRIVATE_KEY` | Sim\*       | Private key da wallet (sem 0x)           |
| `POLY_ADDRESS`     | Sim\*       | Endereco da wallet (com 0x)              |
| `MARTY_ORIGIN`     | Sim         | URL do Marty para CORS                   |
| `RUTH_URL`         | Nao         | URL interna de Ruth (health check)       |
| `JONAH_URL`        | Nao         | URL interna de Jonah (predictions)       |
| `JONAH_DB_URL`     | Nao         | URL do Jonah DB (health check)           |
| `QDRANT_URL`       | Nao         | URL do Qdrant (health check)             |
| `PORT`             | Nao         | Porta do servidor (default: 3000)        |
| `LOG_LEVEL`        | Nao         | Nivel de log (default: info)             |
| `DRY_MODE`         | Nao         | Simular trades sem CLOB (default: false) |

\*Obrigatorio para trading real, pode ficar vazio em DRY_MODE.

### Marty (Dashboard)

| Variavel                   | Obrigatorio | Descricao                                 |
| -------------------------- | ----------- | ----------------------------------------- |
| `NEXT_PUBLIC_WENDY_URL`    | Sim         | URL **publica** de Wendy (browser acessa) |
| `NEXT_PUBLIC_WENDY_WS_URL` | Sim         | WebSocket URL de Wendy (`wss://...`)      |

**Nota:** Marty nunca acessa Jonah diretamente. Todas as chamadas sao proxied via Wendy.

### Jonah (AI Analyst)

| Variavel             | Obrigatorio | Descricao                                    |
| -------------------- | ----------- | -------------------------------------------- |
| `WENDY_URL`          | Sim         | URL interna de Wendy                         |
| `RUTH_SECRET`        | Sim         | Segredo para auth (mesmo valor)              |
| `OPENAI_API_KEY`     | Sim         | API key da OpenAI (GPT-5)                    |
| `GPT_MODEL`          | Sim         | Modelo a usar (default: gpt-5)               |
| `JONAH_DATABASE_URL` | Sim         | PostgreSQL do Jonah (read-write)             |
| `DATABASE_URL`       | Sim         | PostgreSQL de Wendy (read-only, learning)    |
| `QDRANT_HOST`        | Sim         | Host do Qdrant                               |
| `QDRANT_PORT`        | Sim         | Porta do Qdrant (default: 6333)              |
| `WEIGHT_LGBM`        | Nao         | Peso do LightGBM no ensemble (default: 0.20) |
| `WEIGHT_CHRONOS`     | Nao         | Peso do Chronos (default: 0.25)              |
| `WEIGHT_OPENMETEO`   | Nao         | Peso do Open-Meteo (default: 0.30)           |
| `WEIGHT_RAG`         | Nao         | Peso do RAG (default: 0.25)                  |
| `LEARNING_HOUR_UTC`  | Nao         | Hora UTC do learning loop (default: 6)       |
| `PORT`               | Nao         | Porta do servidor (default: 8000)            |

Wendy tambem aceita chaves operacionais adicionais no `app_config`:

- `AI_TRADING_ENABLED` (default `false`, bloqueia execucao de `/trigger` mas mantem previsao/advisory)
- `AI_MIN_EDGE` (default `0.03`)
- `AI_RELIABILITY_FLOOR` (default `0.45`)

### Autenticacao entre servicos

Todos os servicos internos usam o header `x-internal-secret` com o valor de `RUTH_SECRET`:

```
Ruth  --x-internal-secret--> Wendy
Ruth  --x-internal-secret--> Jonah
Jonah --x-internal-secret--> Wendy
```

Marty usa JWT via httpOnly cookie para autenticacao com Wendy.

## Producao

| Servico  | URL publica                | Host interno                 |
| -------- | -------------------------- | ---------------------------- |
| Wendy    | `https://wendy.wozark.com` | `srv-captain--wendy:3000`    |
| Marty    | `https://marty.wozark.com` | SPA exportada via nginx      |
| Ruth     | interno                    | `srv-captain--ruth:8080`     |
| Jonah    | interno                    | `srv-captain--jonah:8000`    |
| Wendy DB | interno + porta externa    | `srv-captain--wbot-db:5432`  |
| Jonah DB | interno + porta externa    | `srv-captain--jonah-db:5432` |
| Qdrant   | interno                    | `srv-captain--qdrant:6333`   |

## Health checks

```bash
bash scripts/health-check.sh
ssh root@168.231.70.56 'bash -s' < scripts/health-check-internal.sh
```

`health-check.sh` verifica Wendy, Marty e a porta externa do PostgreSQL. `health-check-internal.sh` inclui Ruth, Jonah e a conectividade interna do banco.

## Estacoes atuais

As estacoes ativas vivem no codigo de Wendy/Jonah e hoje sao 10 aeroportos dos EUA:

`KSEA`, `KLAX`, `KSFO`, `KDAL`, `KAUS`, `KHOU`, `KORD`, `KLGA`, `KMIA`, `KATL`

## Observacoes

- O `README` anterior ainda descrevia Marty como React/Vite e este repo como "orchestration" puro; o workspace atual inclui os subrepos locais.
- O documento `docs/2026-03-23-v5-architecture-design.md` e historico e nao reflete todas as mudancas posteriores.
- O schema de banco mais atual permanece em `docs/database-schema.md`.
