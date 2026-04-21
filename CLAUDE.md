# CLAUDE.md — Wozark Master

## Language

- Comunicação: **Português (BR)** — toda conversa, explicações, status
- Código (variáveis, funções, comentários, commits) em **inglês**

## Project

Wozark é um sistema de auto-trading em Polymarket sobre temperatura máxima diária. 4 serviços deployados no CapRover, comunicação via HTTP + WebSocket.

**CapRover panel:** https://captain.wozark.com/

## Architecture

```
Ruth (Rust/Axum)         Wendy (TypeScript/Fastify)         Marty (React/Next 16)        Jonah (Python/FastAPI)
Sensor                   Trading brain                       Dashboard                     Learning analyst
─ Synoptic /timeseries   ─ Receives METAR                    ─ Bento UI                    ─ LEARNING-ONLY ⚠️
  every :00,:05,...,:55   ─ runningMaxC = max(prev,tempC)    ─ Everforest dark             ─ /trigger DISABLED
  + extra :53 slot       ─ Bucket detection                  ─ Manrope font                ─ Ensemble: LightGBM,
─ Per-station retry 3×    ─ Guards (local first)             ─ BRT timezone                  Chronos, Open-Meteo,
─ TGFTP fallback         ─ CLOB BUY/ROTATE                  ─ Recharts + WS auto-update    RAG (Qdrant)
─ PWS → Jonah only       ─ FOK + GTC fallback                ─ Reads via Wendy REST+WS    ─ GPT-5 final decision
─ Logs to Wendy /log     ─ Postgres (Drizzle)                  Never touches DB           ─ Saves every Ruth obs
                         ─ Sub-400ms hot path                                              ─ Nightly RAG learning
                         ─ WS broadcaster                                                    /prediction → Wendy
```

## Services

| Service   | Stack                                          | URL              | Port | Status               |
| --------- | ---------------------------------------------- | ---------------- | ---- | -------------------- |
| **Ruth**  | Rust, Axum, Tokio                              | internal only    | 8080 | live                 |
| **Wendy** | TypeScript, Fastify 5, Drizzle, py-clob-client | wendy.wozark.com | 3000 | live                 |
| **Marty** | Next.js 16, React 19, Recharts, Everforest     | marty.wozark.com | 80   | live                 |
| **Jonah** | Python 3.12, FastAPI, GPT-5, LightGBM, Qdrant  | internal only    | 8000 | live (learning-only) |

Each project has its own `CLAUDE.md` and `README.md`. Open Claude in the specific project directory to work on it.

## Communication

**Internal auth:** all service-to-service calls use header `x-internal-secret: <RUTH_SECRET>`.

```
Ruth → Wendy:  POST /signal       (METAR signal — trade trigger)
Ruth → Wendy:  POST /log          (Ruth diagnostic events: SYNOPTIC_DOWN, etc.)
Ruth → Jonah:  POST /signal       (METAR + PWS — RAG/learning input)
Jonah → Wendy: POST /prediction   (advisory — broadcast to Marty)
Jonah → Wendy: POST /trigger      (DELETED — endpoint removed 2026-04-16)
Marty ↔ Wendy: REST (JWT)         (positions, balance, logs, config, history)
Marty ← Wendy: WebSocket          (new_metar, trade_executed, position_update, etc.)
```

Internal hosts:

- Ruth → Wendy: `http://srv-captain--wendy:3000`
- Ruth → Jonah: `http://srv-captain--jonah:8000`
- Wendy → Postgres: `srv-captain--wbot-db:5432`
- Jonah → Postgres: `srv-captain--jonah-db:5432`
- Jonah → Qdrant: `srv-captain--qdrant:6333`

## Stations (10, US)

| Station       | ICAO | Unit | TZ                  |
| ------------- | ---- | ---- | ------------------- |
| Seattle       | KSEA | F    | America/Los_Angeles |
| Los Angeles   | KLAX | F    | America/Los_Angeles |
| San Francisco | KSFO | F    | America/Los_Angeles |
| Dallas        | KDAL | F    | America/Chicago     |
| Austin        | KAUS | F    | America/Chicago     |
| Houston       | KHOU | F    | America/Chicago     |
| Chicago       | KORD | F    | America/Chicago     |
| New York      | KLGA | F    | America/New_York    |
| Miami         | KMIA | F    | America/New_York    |
| Atlanta       | KATL | F    | America/New_York    |

## Signal flow (current — Synoptic-first)

```
1. Ruth slot scheduler fires at wall-clock minutes :00,:05,:10,:15,:20,:25,:30,:35,:40,:45,:50,:53,:55 + 1s grace
2. GET https://api.synopticdata.com/v2/stations/timeseries?stids=...&recent=10&vars=...
   → returns ALL observations from last 10min per station (1-3 readings + any SPECI)
3. Per-station processing:
   • temp_c, dewpoint, wind, pressure, ceiling, wx_string come from Synoptic DIRECT vars
     (fresh sensor readings, NOT parsed from hourly METAR text)
   • metar_raw used only to enrich cloud_layers, visibility, sea_level_pressure
   • Dedup by obs_time → each unique reading sent once
4. Ruth → Wendy POST /signal {type:"METAR"} per reading
5. Ruth → Jonah POST /signal (fire-and-forget with 1 retry)
6. PWS poll every 5min → Jonah ONLY (never Wendy)
7. Wendy: runningMaxC = Math.max(runningMaxC, signal.tempC). state.lastMetarAt = signal.metarTime.
8. Bucket crossing → guards → BUY (or ROTATE if existing position different bucket)
9. Wendy → WS broadcast 'new_metar' → Marty triggerRefresh → all UI re-fetches
10. Jonah saves every obs to metar_readings (RAG density). Runs ensemble + GPT-5 → /prediction (advisory only)
```

## Why /timeseries (not /latest)

Synoptic's `/timeseries?recent=10` returns ALL obs in the last 10min. Wins:

- Catches off-cycle SPECI updates with rich data (cloud_layers, etc.)
- Survives a missed poll cycle — next poll backfills the gap
- Feeds Jonah's RAG with full 5-min density
- Per-station retry (3 attempts × 500ms/1.5s/3s backoff) before TGFTP fallback

## Trading rules

- `tradingEnabled=false` (config in DB) = absolute kill switch
- `metarTradingEnabled=false` blocks signal-triggered trades
- Trade fires on EVERY new bucket crossing detected via Synoptic — does NOT wait for hourly METAR confirmation
- ROTATE: BUY new first → SELL old + harvest in parallel
- Border zone 0.45-0.55 → skip, wait for next signal
- Daily loss cap before non-rotate BUYs
- FOK with GTC fallback. Verify via `getOrder().size_matched` always.
- No stop-loss. Hold to resolution.
- Jonah `/trigger` endpoint was DELETED from Wendy (2026-04-16). Pure METAR trading. Don't recreate without explicit product decision.
- **Jonah defer veto** (2026-04-16): entries AND rotations consult Jonah. If Jonah points to a higher bucket with ≥60% confidence and that bucket is priced ≥35c (≥12c above current), Wendy holds 5-10min instead of buying/rotating into the cheap bucket. Still "learning-only" for triggering trades — Jonah never initiates. Heuristic, not backtested — watch for false holds in prod.

## Time / Locale

- Server logs: UTC (Docker timestamp, can't change)
- Wendy DB timestamps: `timestamptz` (UTC under the hood)
- Marty UI: **BRT (America/Sao_Paulo) everywhere** except one local-clock chip on the station page
- "age" metric uses `now − validUtc` (real obs time)

## Deploy

Each project deploys independently via CapRover git push:

```
feat/xxx → main (auto-deploy)
```

Updating Wendy doesn't affect Ruth/Marty/Jonah. Each repo has its own remote.

## Working with Projects

```bash
cd ~/personal/wozark/wbot-ruth     # Sensor (Rust)
cd ~/personal/wozark/wbot-wendy    # Trading brain (TypeScript)
cd ~/personal/wozark/wbot-marty    # Dashboard (React/Next.js)
cd ~/personal/wozark/wbot-jonah    # Learning analyst (Python)
```

Cross-project orchestration (integration, API contracts): work from this master directory.

## Lint & format (per stack)

| Project | Formatter                   | Linter                       | Config                                  |
| ------- | --------------------------- | ---------------------------- | --------------------------------------- |
| Ruth    | `cargo fmt`                 | `cargo clippy`               | `rustfmt.toml`, `clippy.toml`           |
| Wendy   | `npm run format` (prettier) | `npm run lint` (eslint flat) | `.prettierrc.json`, `eslint.config.js`  |
| Marty   | `npm run format` (prettier) | `npm run lint` (next eslint) | `.prettierrc.json`, `eslint.config.mjs` |
| Jonah   | `ruff format`               | `ruff check`                 | `pyproject.toml`                        |

Wendy uses no-semicolons + single-quote. Marty uses standard Next defaults (semi + double-quote). Don't unify — each stack follows its own convention.

## Critical rules (cross-cutting)

- Never describe Jonah trigger behavior as active. Verify `wbot-jonah/src/proxy.py:26` first.
- Synoptic is primary METAR source. TGFTP is fallback only.
- PWS → Jonah only, never Wendy.
- METAR temp / timestamp comes from Synoptic direct vars, NOT from parsing the hourly METAR string.
- Ruth uses `/timeseries?recent=10` + slot scheduler `[0,5,10,...,50,53,55]`.
- `runningMaxC` advances only from real sensor readings (`signal.tempC`).
- DB writes are fire-and-forget in trade hot path.
- All UI displays (Marty) use BRT.
- Show city names, not ICAO codes (in user-facing UI).
- Don't add unsanctioned fallbacks/heuristics — when in doubt, ask before changing trading logic.

## Workflow

- Plan first for non-trivial work (3+ steps or arch decisions). Skip plan for trivial fixes.
- Use subagents to keep main context clean for focused exploration / audit.
- After any user correction: update relevant CLAUDE.md + memory.
- Verify before "done": `cargo test`, `npm run build`, `npm test`, manual UI check.
- Demand elegance balanced with simplicity — skip over-engineering on trivial fixes.

### Multi-service changes

- When changing an API contract (route, payload, header), grep ALL 4 service dirs for callers before editing.
- Never assume a change to Wendy is isolated — Ruth calls it, Marty reads it, Jonah posts to it.
- After changing Wendy endpoints: update Wendy CLAUDE.md endpoint table + this file's Communication section.

### Trading logic changes (high-stakes)

- NEVER change trading logic (guards, sizing, bucket detection, CLOB execution) without reading the full function first.
- Trading changes get ONE well-planned edit, never iterative "let me try this" patches.
- If a trading fix helps one station but could hurt another, say so in the same sentence — never bury trade-offs.

## Reporting changes — honesty rule (hard requirement)

**Never embale hypothesis as certainty.** The user pays in money and attention
when the system is wrong. Marketing language in summaries and commits compounds
trust debt.

- NÃO usar "resolve", "protege", "limpa", "captura", "elimina", "garante", "elegante",
  "robusto", "sólido", "correto" sem backtest concreto com dados
- SEMPRE ao propor mudança, explicitar no final: (a) hipótese central,
  (b) cenários onde quebra, (c) nível de confiança — palpite / palpite informado /
  medido / backtested, (d) o que só saberemos após ver em prod por N dias
- Commits seguem Conventional Commits (regra global). Para heurísticas sem validação,
  usar tag no description: `feat: [hypothesis] X` — nunca `feat: X resolves Y` sem dados
- Se não há dado, dizer literalmente: "palpite informado — não validado"
- Antes de apresentar como solução, perguntar mentalmente: tenho backtest ou é
  opinião? Se é opinião, dizer que é opinião.
- Ao explicar resultado depois do commit: liderar com incerteza, não confiança.
  "Deploy saiu. Comportamento esperado em cenários A, B. Vamos observar por X
  dias antes de chamar de win."
- Proativamente apontar trade-offs que o usuário não pediu mas são relevantes.
  Se um fix resolve KORD mas deixa KLGA exposto, dizer isso na mesma frase
  do fix — não enterrar no final.
- Sugerir arquitetura ambiciosa quando o projeto pede, não só o que o usuário
  pediu explicitamente. Se um amador vs bots precisa de multi-source + modelo
  estatístico + order book awareness + backtest, dizer isso abertamente em vez
  de aceitar filtro binário simples.

## User preferences (Tales)

- Timezone BRT (America/Sao_Paulo).
- No over-engineering. Delete dead code, never keep it for "future use".
- Always consult memory before assuming.
- "Deploy" = git push (CapRover auto-deploys on push to main).
