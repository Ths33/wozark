# Wozark

Sistema de auto-trading sobre temperatura máxima diária em Polymarket. 4 serviços, deploy CapRover (https://captain.wozark.com).

## Architecture

```
Ruth (Rust)              Wendy (TS)              Marty (Next.js)         Jonah (Python)
sensor                   trading brain           dashboard               learning analyst
                                                                         (LEARNING-ONLY)

Synoptic /timeseries  ─► Ruth ─POST /signal─► Wendy ─POST /trigger─► (blocked)
TGFTP (fallback)      ─►       │                    ─POST /prediction─► (advisory)
WU PWS                ─►       └─POST /signal─► Jonah ─ensemble + GPT-5
                                                       └─► RAG + nightly learning
                                                            └─► outcomes (Qdrant)

                          Wendy ─WS─► Marty (real-time UI updates)
                          Marty ─REST(JWT)─► Wendy (API)
```

## Services

| Service | Stack                                             | URL                      | Port |
| ------- | ------------------------------------------------- | ------------------------ | ---- |
| Ruth    | Rust + Axum                                       | internal                 | 8080 |
| Wendy   | TypeScript + Fastify 5 + Drizzle                  | https://wendy.wozark.com | 3000 |
| Marty   | Next.js 16 + React 19 + Recharts                  | https://marty.wozark.com | 80   |
| Jonah   | Python 3.12 + FastAPI + GPT-5 + LightGBM + Qdrant | internal                 | 8000 |

Cada projeto tem seu próprio `README.md` + `CLAUDE.md` com detalhes.

## What it does

- Ruth polla Synoptic API a cada ~5min (slots `:00,:05,...,:50,:53,:55` + retry per-station)
- Cada leitura fresca do sensor é mandada pra Wendy como signal
- Wendy mantém `runningMaxC` por estação, detecta cruzamento de bucket de temperatura, executa BUY/ROTATE no Polymarket via CLOB
- Edge: trade dispara no minuto que Synoptic expõe nova máxima do sensor — antes do METAR oficial horário (~30-50min de vantagem sobre bots que dependem de TGFTP)
- Marty mostra tudo em real-time via WebSocket
- Jonah aprende paralelamente (modo learning-only por 3 meses): ingere todo signal, roda ensemble (LightGBM + Chronos + Open-Meteo + RAG) + GPT-5, registra outcomes no Qdrant

## Stations (10 US)

KSEA, KLAX, KSFO, KDAL, KAUS, KHOU, KORD, KLGA, KMIA, KATL.

## Setup local

Cada serviço se desenvolve isoladamente:

```bash
cd wbot-ruth && cargo run
cd wbot-wendy && npm install && npm run dev
cd wbot-marty && npm install && npm run dev
cd wbot-jonah && pip install -r requirements.txt && python -m src.main
```

Variáveis de ambiente em cada projeto (ver respectivo README).

## Deploy

CapRover git push para `main` em cada repo. Auto-deploy. Cada serviço é independente.

## Documentação operacional

Detalhes técnicos por projeto:

- [Ruth](./wbot-ruth/README.md) — sensor Synoptic + TGFTP
- [Wendy](./wbot-wendy/README.md) — trading brain + CLOB
- [Marty](./wbot-marty/README.md) — dashboard real-time
- [Jonah](./wbot-jonah/README.md) — learning analyst (currently learning-only)

Conventions de orquestração entre serviços e regras de trading: ver [CLAUDE.md](./CLAUDE.md) raiz.
