# Wozark — Architecture (from code, 2026-04-16)

## System Overview

```mermaid
graph TB
    subgraph External["External APIs"]
        SYN["Synoptic Data<br/><i>/timeseries?recent=120</i><br/><i>6-token rotation</i>"]
        TGFTP["TGFTP (NOAA)<br/><i>Fallback + parallel :51/:53</i>"]
        WU["Weather Underground<br/><i>PWS — 3 IDs/station</i>"]
        GAMMA["Gamma API<br/><i>Markets + prices (5min cache)</i>"]
        CLOB["Polymarket CLOB<br/><i>FOK/GTC + EIP-712</i>"]
        OMET["Open-Meteo<br/><i>NWP forecast (weight 0.30)</i>"]
        GPT5["OpenAI GPT-5<br/><i>Claude Sonnet fallback</i>"]
    end

    subgraph Helsinki["CapRover — Helsinki VPS"]
        direction TB

        subgraph Ruth["Ruth (Rust/Axum) :8080"]
            R_POLL["Poller<br/><i>14 slots/hour + hot-poll :50-:58</i>"]
            R_SEND["Sender<br/><i>Circuit breaker + retry buffer</i>"]
        end

        subgraph Wendy["Wendy (TypeScript/Fastify) :3000"]
            W_SIG["Signal Pipeline<br/><i>runningMaxC → bucket → guards</i>"]
            W_TRADE["Trade Engine<br/><i>BUY / SELL / ROTATE</i>"]
            W_MON["Monitor<br/><i>3min: auto-sell, sync, retry</i>"]
            W_WS["WS Broadcaster<br/><i>9 event types</i>"]
            WDB[("Postgres wbot_prod<br/><i>metar_obs, trades, logs</i>")]
        end

        subgraph Jonah["Jonah (Python/FastAPI) :8000 — LEARNING ONLY"]
            J_INGEST["Ingestion<br/><i>Buffer + DB (every reading)</i>"]
            J_ENS["Ensemble<br/><i>LightGBM·Chronos·OpenMeteo·RAG</i>"]
            J_GPT["GPT-5 Decision<br/><i>10-point analysis</i>"]
            J_LEARN["Nightly Learning<br/><i>Resolve → Qdrant + DB</i>"]
            JDB[("Postgres jonah_prod<br/><i>7 tables</i>")]
            JQ[("Qdrant :6333<br/><i>12-dim vectors</i>")]
        end

        subgraph Marty["Marty (Next.js 16) :80"]
            M_UI["Dashboard<br/><i>7 pages, Everforest dark</i>"]
        end
    end

    %% Ruth ← External
    SYN --> R_POLL
    TGFTP -.-> R_POLL
    WU --> R_POLL

    %% Ruth → downstream (METAR goes to BOTH Wendy and Jonah)
    R_POLL --> R_SEND
    R_SEND -->|"POST /signal<br/>(METAR — circuit breaker)"| W_SIG
    R_SEND -->|"POST /signal<br/>(METAR — fire-and-forget)"| J_INGEST
    R_SEND -->|"POST /signal<br/>(PWS — Jonah only)"| J_INGEST

    %% Wendy trade flow
    W_SIG -->|"bucket crossing"| W_TRADE
    W_TRADE -->|"FOK/GTC"| CLOB
    W_TRADE -->|"save"| WDB
    W_SIG -->|"broadcast"| W_WS
    W_MON -->|"auto-sell, retry"| W_TRADE
    GAMMA -->|"market cache"| W_SIG

    %% Jonah pipeline
    J_INGEST --> JDB
    J_INGEST --> J_ENS
    OMET --> J_ENS
    JQ -->|"RAG similar days<br/>(weight 0.25)"| J_ENS
    J_ENS --> J_GPT
    GPT5 --> J_GPT
    J_GPT -->|"POST /prediction<br/>(advisory only)"| W_WS

    %% Jonah learning (nightly)
    J_LEARN -->|"store outcomes"| JQ
    J_LEARN -->|"store outcomes"| JDB
    WDB -->|"fetch actual max"| J_LEARN

    %% Marty
    W_WS -->|"WebSocket"| M_UI
    M_UI -->|"REST (JWT)"| Wendy

    %% Styling
    classDef external fill:#4a4a4a,stroke:#666,color:#fff
    classDef rust fill:#ce422b,stroke:#a33,color:#fff
    classDef ts fill:#3178c6,stroke:#256,color:#fff
    classDef python fill:#3776ab,stroke:#256,color:#fff
    classDef react fill:#61dafb,stroke:#49b,color:#000
    classDef db fill:#336791,stroke:#245,color:#fff
    classDef ai fill:#10a37f,stroke:#0a7d5a,color:#fff

    class SYN,TGFTP,WU,GAMMA,CLOB,OMET external
    class GPT5 ai
    class R_POLL,R_SEND rust
    class W_SIG,W_TRADE,W_MON,W_WS ts
    class J_INGEST,J_ENS,J_GPT,J_LEARN python
    class M_UI react
    class WDB,JDB,JQ db
```

## Signal Hot Path (150-400ms)

```mermaid
sequenceDiagram
    participant SYN as Synoptic API
    participant R as Ruth
    participant W as Wendy
    participant C as CLOB
    participant M as Marty

    Note over R: Slot fires (14×/hour)
    R->>SYN: GET /timeseries?recent=120
    SYN-->>R: 1-3 obs per station
    R->>R: Dedup + T-group parse

    loop Per unique observation
        R->>W: POST /signal {tempC, tempPrecise, source}

        W->>W: runningMaxC = max(prev, tempC)
        W->>W: Compute bucket

        alt Bucket changed
            W->>W: runGuards [window→resolved→price→border→loss→book→lock]

            alt Guards pass
                W->>C: BUY YES (FOK, 3 retries +1¢)
                C-->>W: verify size_matched
                W->>M: broadcast('trade_executed')
            else Reject
                W->>M: broadcast('trade_skipped')
            end
        end
    end
```

## Jonah Prediction Pipeline

```mermaid
sequenceDiagram
    participant R as Ruth
    participant J as Jonah
    participant OM as Open-Meteo
    participant QD as Qdrant
    participant GPT as GPT-5
    participant W as Wendy

    R->>J: POST /signal (METAR + PWS)
    J->>J: Buffer + save to DB

    Note over J: Scheduler (xx:48 or dawn)

    par 4-source ensemble
        J->>J: LightGBM quantiles (0.20)
        J->>J: Chronos-Bolt series (0.25)
        J->>OM: GET /forecast (0.30)
        J->>QD: similar days (0.25)
    end

    J->>J: combine → best bucket + timing
    J->>GPT: ensemble + METAR + market prices
    GPT-->>J: {bucket, confidence, reason}
    J->>W: POST /prediction (advisory)
    W->>W: broadcast('ai_prediction')

    Note over J: Nightly (10 UTC)
    J->>W: fetch actual max from wbot_prod
    J->>QD: store resolved outcome
```
