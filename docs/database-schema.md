# Database Schema — Wozark V5

> Fonte de verdade para bancos, contratos entre servicos, retencao e estado atual do Qdrant.
> Atualizado em 2026-04-08.

## Databases

| Database | Host interno | Porta externa | Uso |
| --- | --- | --- | --- |
| `wbot_prod` | `srv-captain--wdb:5432` | `15432` | Wendy read/write, Jonah learning read-only |
| `jonah_prod` | `srv-captain--jonah-db:5432` | `25432` | Jonah read/write |
| `Qdrant` | `srv-captain--qdrant:6333` | — | RAG do Jonah |

## Retencao operacional

Em `2026-04-08`, o cleanup operacional removeu dados anteriores a `2026-04-01 00:00:00+00` nas tabelas de runtime.

### Wendy

- `logs`
- `trades`
- `metar_observations`
- `pws_observations`
- `jonah_triggers`

### Jonah

- `pws_readings`
- `metar_readings`
- `session_updates`
- `day_sessions`
- `trigger_history`

`learning_outcomes` ja comecava em `2026-04-01`, entao nao precisou de purge adicional.

No mesmo dia, o Qdrant foi corrigido:

- `weather_days_v4` foi removida
- `weather_days_v5` foi rebuildada em duas camadas:
  - `18,604` dias historicos de `data/historical/all_stations.csv`
  - `70` dias recentes de `learning_outcomes`
- resultado final do rebuild: `18,674` pontos

## Data Flow

```text
Ruth (camelCase JSON)
  ├─ POST /signal -> Wendy
  └─ POST /signal -> Jonah

Jonah
  ├─ POST /prediction -> Wendy
  └─ POST /trigger -> Wendy
```

### Convencao de nomes

| Camada | Convencao | Exemplo |
| --- | --- | --- |
| Ruth JSON | camelCase | `tempC`, `metarRaw`, `capturedAt` |
| Wendy TypeScript | camelCase | `tempC`, `metarRaw` |
| Wendy DB | snake_case | `temp_c`, `metar_raw`, `captured_at` |
| Jonah Python | camelCase entrada / snake_case DB | `body.get("tempC")`, `metar_raw` |

## Wendy DB (`wbot_prod`)

Schema real: `wbot-wendy/src/shared/db/schema.ts`

### `metar_observations`

Campos principais:

- `station`
- `temp_c`
- `dewpoint_c`
- `humidity_pct`
- `wind_deg`
- `wind_kt`
- `gust_kt`
- `visibility_m`
- `cloud_layers`
- `pressure_hpa`
- `max_temp_c_6h`
- `min_temp_c_6h`
- `sea_level_pressure_hpa`
- `wx_string`
- `auto_station`
- `metar_type`
- `metar_raw`
- `valid_utc`
- `captured_at`
- `trace_id`
- `created_at`

Indices relevantes:

- `(station, valid_utc)`
- unicidade `uq_metar_station_valid_raw (station, valid_utc, metar_raw)`

Observacao:

- essa unicidade foi adicionada para impedir replay/duplicata do mesmo boletim.

### `pws_observations`

Campos principais:

- `station`
- `median_temp_c`
- `reading_count`
- `readings`
- `trace_id`
- `captured_at`
- `created_at`

Indice: `(station, captured_at)`

### `trades`

Campos principais:

- `trace_id`
- `station`
- `action`
- `side`
- `bucket`
- `token_id`
- `amount`
- `shares`
- `price`
- `order_id`
- `fill_status`
- `signal_type`
- `market_snapshot`
- `dry_run`
- `created_at`

`signal_type` hoje pode carregar:

- `METAR`
- `PWS`
- `MANUAL`
- `AI_TRIGGER`
- `AI_UPGRADE`
- `EXTERNAL`

### `logs`

Campos principais:

- `trace_id`
- `service`
- `station`
- `level`
- `category`
- `message`
- `metadata`
- `created_at`

### `app_config`

Chaves operacionais importantes:

- `TRADING_ENABLED`
- `TRADING_MAX_SIZE`
- `TRADING_MAX_DAILY_LOSS`
- `ENABLED_STATIONS`
- `AUTH_PASSWORD`
- `AI_MIN_EDGE`
- `AI_RELIABILITY_FLOOR`

Estado atual relevante:

- nao existe mais toggle operacional separado para AI trading; `/trigger` sempre chega ao runtime do Wendy e os bloqueios passam a ser so de guard/contrato

### `jonah_triggers`

Persistencia do resultado de `/trigger`:

- station
- bucket
- signal
- confidence
- timing
- range_prob
- market_price
- status
- reason
- trace_id
- created_at

### `auth_sessions`

- `token_hash`
- `expires_at`
- `revoked`
- `created_at`

## Jonah DB (`jonah_prod`)

Schema real: `wbot-jonah/src/db.py`

### `metar_readings`

Campos principais:

- `station`
- `temp_c`
- `dewpoint_c`
- `humidity_pct`
- `wind_deg`
- `wind_kt`
- `gust_kt`
- `visibility_m`
- `cloud_layers`
- `pressure_hpa`
- `metar_raw`
- `max_temp_c_6h`
- `valid_utc`
- `captured_at`

Observacao:

- Jonah salva METAR apenas quando `metar_raw` muda.

### `pws_readings`

- `station`
- `median_c`
- `reading_count`
- `solar_radiation`
- `uv`
- `raw_readings`
- `captured_at`

### `day_sessions`

- `station`
- `date`
- `dawn_bucket`
- `dawn_confidence`
- `current_bucket`
- `current_confidence`
- `status`
- `timing`
- `range_prob`
- `forecast_max`
- `created_at`
- `locked_at`
- `resolved_at`

Unico por `(station, date)`.

### `session_updates`

- `session_id`
- `phase`
- `bucket`
- `confidence`
- `timing`
- `reasoning`
- `sources`
- `market_snapshot`
- `metar_at_update`
- `pws_at_update`
- `created_at`

Observacao importante:

- a partir de `2026-04-08`, `market_snapshot` voltou a ser salvo corretamente.

### `learning_outcomes`

- `station`
- `date`
- `actual_max_c`
- `actual_bucket`
- `dawn_bucket`
- `final_bucket`
- `was_correct`
- `error_value`
- `market_favorite_bucket`
- `market_was_correct`
- `jonah_beat_market`
- `sources_accuracy`
- `conditions`
- `evolution`
- `created_at`

Unico por `(station, date)`.

Estado atual conhecido:

- linhas atuais cobrem `2026-04-01` ate `2026-04-07`
- historico antigo de `market_favorite_bucket` ficou `NULL` porque `session_updates.market_snapshot` nao estava sendo persistido
- isso faz o `beat_market_rate` historico antigo ser pouco confiavel

### `buffer_snapshots`

- `station`
- `snapshot`
- `updated_at`

Mantem apenas o ultimo snapshot por estacao.

### `trigger_history`

Historico bruto de decisao de trigger do Jonah.

## Qdrant

Implementacao real: `wbot-jonah/src/rag.py`

- collection: `weather_days_v5`
- dimensions: `12`
- distance: `COSINE`
- point id: hash deterministico de `station:date`

Observacao operacional:

- o banco relacional e o Qdrant agora estao alinhados no corte `2026-04-01+`
- `weather_days_v4` foi removida do runtime
- a `weather_days_v5` atual mistura memoria historica longa com a camada recente rica do runtime

### Vetor

| Index | Campo | Normalizacao |
| --- | --- | --- |
| 0 | `temp_c` | `/ 40` |
| 1 | `humidity_pct` | `/ 100` |
| 2 | `wind_kt` | `min(val, 30) / 30` |
| 3 | `hour_local` | `/ 24` |
| 4 | `month` | `/ 12` |
| 5 | `dewpoint_c` | `/ 30` |
| 6 | `gust_kt` | `min(val, 40) / 40` |
| 7 | `station_hash` | hash modulo 100 |
| 8 | `pressure_hpa` | normalizado em torno de `980-1040` |
| 9 | `sin(wind_deg)` | componente circular |
| 10 | `cloud_cover` | `/ 4` |
| 11 | `solar_peak` | `min(val, 1000) / 1000` |

### Payload tipico

- `station`
- `date`
- `memory_source`
- `actual_max`
- `actual_bucket`
- `predicted_bucket`
- `was_correct`
- `confidence`
- `error_value`
- `evolution`
- `sources_accuracy`
- `intraday_accuracy`
- `intraday_drift`

## Contratos principais

### Ruth -> Wendy/Jonah METAR

```json
{
  "type": "METAR",
  "station": "KAUS",
  "tempC": 26.7,
  "tempF": 80,
  "metarType": "METAR",
  "metarRaw": "METAR KAUS 082253Z ...",
  "metarTime": "2026-04-08T22:53:00Z",
  "capturedAt": "2026-04-08T22:55:39.079Z",
  "traceId": "ruth-metar-kaus-20260408-225539023"
}
```

### Jonah -> Wendy `/prediction`

```json
{
  "station": "KAUS",
  "prediction": {
    "bucket": "80-81°F",
    "confidence": 0.7,
    "reasoning": "GPT-5 decision with ensemble context",
    "phase": "pre_metar",
    "predicted_at": "2026-04-08T22:50:44Z"
  }
}
```

### Jonah -> Wendy `/trigger`

```json
{
  "station": "KAUS",
  "bucket": "80-81°F",
  "signal": "BUY",
  "confidence": 0.7,
  "timing": "STRONG",
  "rangeProb": 0.36,
  "traceId": "jonah-trigger-kaus-1775688644",
  "learningProfile": {
    "samples": 7,
    "accuracy": 0.286,
    "hourly": {
      "17": { "samples": 3, "accuracy": 0.667 }
    }
  }
}
```

## Qualidade de dados

- Wendy METAR truth esta mais forte depois de:
  - dedupe por `station + valid_utc + metar_raw`
  - limpeza de linhas quebradas
  - parser de rollover de mes corrigido em Ruth
- Jonah learning esta utilizavel para filtros simples de hora e estacao.
- `beat_market_rate` so passa a ficar realmente confiavel para os dias gravados apos a correcao de `market_snapshot`.
- o RAG agora preserva o historico longo e mantem os dias recentes ricos por cima.
