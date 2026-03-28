# Database Schema — Wozark V5

> Single source of truth for all database structures, field mappings, and data contracts.
> Last updated: 2026-03-28

## Databases

| Database | Host (internal) | Host (external) | Port | Password | Used by |
|----------|----------------|-----------------|------|----------|---------|
| `wbot_prod` | `srv-captain--wbot-db:5432` | `45.93.138.190:15432` | 5432/15432 | `92b2602fbd1205f5` | Wendy (read/write), Jonah learning (read-only) |
| `jonah_prod` | `srv-captain--jonah-db:5432` | `45.93.138.190:25432` | 5432/25432 | `3f233c99a6c8e4ad` | Jonah (read/write) |
| Qdrant | `srv-captain--qdrant:6333` | — | 6333 | — | Jonah RAG (read/write) |

---

## Data Flow: Ruth → Wendy + Jonah

```
Ruth (Rust, serde camelCase)
  │
  ├─ POST /signal → Wendy (Authorization: Bearer RUTH_SECRET)
  │   body.tempC → metar_observations.temp_c
  │   body.metarRaw → metar_observations.metar_raw
  │
  └─ POST /signal → Jonah (x-ruth-secret: RUTH_SECRET)
      body.tempC → buffer.add_metar(temp_c=body["tempC"])
      body.metarRaw → metar_readings.metar_raw
```

### Field Name Convention

| Layer | Convention | Example |
|-------|-----------|---------|
| Ruth JSON output | camelCase (serde) | `tempC`, `dewpointC`, `metarRaw`, `windKt` |
| Wendy TypeScript | camelCase (Zod) | `tempC`, `dewpointC`, `metarRaw` |
| Wendy DB columns | snake_case (Drizzle) | `temp_c`, `dewpoint_c`, `metar_raw` |
| Jonah Python input | camelCase (from JSON) | `body.get("tempC")`, `body.get("metarRaw")` |
| Jonah DB columns | snake_case (psycopg2) | `temp_c`, `dewpoint_c`, `metar_raw` |

---

## 1. Wendy DB (`wbot_prod`)

Schema: `wbot-wendy/src/shared/db/schema.ts` (Drizzle ORM)

### metar_observations

| Column | Type | Nullable | Default | Source |
|--------|------|----------|---------|--------|
| id | SERIAL | PK | auto | — |
| station | VARCHAR(4) | NOT NULL | — | Ruth: `station` |
| temp_c | REAL | NOT NULL | — | Ruth: `tempC` |
| dewpoint_c | REAL | YES | — | Ruth: `dewpointC` |
| humidity_pct | SMALLINT | YES | — | Ruth: `humidityPct` |
| wind_deg | SMALLINT | YES | — | Ruth: `windDeg` |
| wind_kt | SMALLINT | YES | — | Ruth: `windKt` |
| gust_kt | SMALLINT | YES | — | Ruth: `gustKt` |
| visibility_m | INTEGER | YES | — | Ruth: `visibilityM` |
| cloud_layers | JSONB | YES | — | Ruth: `cloudLayers` [{cover, altFt}] |
| pressure_hpa | REAL | YES | — | Ruth: `pressureHpa` |
| max_temp_c_6h | REAL | YES | — | Ruth: `maxTempC6h` |
| min_temp_c_6h | REAL | YES | — | Ruth: `minTempC6h` |
| sea_level_pressure_hpa | REAL | YES | — | Ruth: `seaLevelPressureHpa` |
| wx_string | VARCHAR(30) | YES | — | Ruth: `wxString` |
| auto_station | BOOLEAN | YES | — | Ruth: `autoStation` |
| metar_type | VARCHAR(5) | YES | — | Ruth: `metarType` |
| metar_raw | TEXT | NOT NULL | — | Ruth: `metarRaw` |
| valid_utc | TIMESTAMPTZ | NOT NULL | — | Ruth: parsed from `metarTime` |
| captured_at | TIMESTAMPTZ | NOT NULL | — | Ruth: `capturedAt` |
| trace_id | VARCHAR(64) | NOT NULL | — | Ruth: `traceId` |
| created_at | TIMESTAMPTZ | — | NOW() | — |

Indexes: `(station, valid_utc)`

### pws_observations

| Column | Type | Nullable | Default | Source |
|--------|------|----------|---------|--------|
| id | SERIAL | PK | auto | — |
| station | VARCHAR(4) | NOT NULL | — | Ruth: `station` |
| median_temp_c | REAL | NOT NULL | — | Wendy calculates from readings |
| reading_count | SMALLINT | NOT NULL | — | `readings.length` |
| readings | JSONB | YES | — | Ruth: `readings` [{pwsId, tempF, ...}] |
| trace_id | VARCHAR(64) | NOT NULL | — | Ruth: `traceId` |
| captured_at | TIMESTAMPTZ | NOT NULL | — | Ruth: `capturedAt` |
| created_at | TIMESTAMPTZ | — | NOW() | — |

Indexes: `(station, captured_at)`

### trades

| Column | Type | Nullable | Default | Source |
|--------|------|----------|---------|--------|
| id | SERIAL | PK | auto | — |
| trace_id | VARCHAR(64) | NOT NULL | — | Wendy/Ruth trace |
| station | VARCHAR(4) | NOT NULL | — | ICAO |
| action | VARCHAR(10) | NOT NULL | — | BUY, SELL |
| side | VARCHAR(3) | NOT NULL | — | YES, NO |
| bucket | VARCHAR(20) | NOT NULL | — | "84-85°F", "12°C" |
| token_id | VARCHAR(128) | YES | — | Polymarket token ID |
| amount | REAL | YES | — | USDC (BUY only) |
| shares | REAL | YES | — | Share count |
| price | REAL | YES | — | Per-share price |
| order_id | VARCHAR(128) | YES | — | CLOB order ID |
| fill_status | VARCHAR(10) | YES | — | FILLED, PARTIAL, FAILED |
| signal_type | VARCHAR(10) | NOT NULL | — | METAR, PWS, MANUAL, AI_UPGRADE, AI_TRIGGER, EXTERNAL |
| market_snapshot | JSONB | YES | — | {yesPrice, noPrice, ...} |
| dry_run | BOOLEAN | — | false | DRY_MODE flag |
| created_at | TIMESTAMPTZ | — | NOW() | — |

Indexes: `(station, created_at)`, `(trace_id)`

### logs

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| id | SERIAL | PK | auto |
| trace_id | VARCHAR(64) | YES | — |
| service | VARCHAR(10) | NOT NULL | wendy, jonah, ruth |
| station | VARCHAR(4) | YES | — |
| level | VARCHAR(10) | NOT NULL | debug, info, warn, error, success |
| category | VARCHAR(20) | YES | signal, trade, guard, trigger, ai |
| message | TEXT | NOT NULL | — |
| metadata | JSONB | YES | — |
| created_at | TIMESTAMPTZ | — | NOW() |

Indexes: `(trace_id)`, `(service, created_at)`, `(station, created_at)`

### app_config

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| key | VARCHAR(50) | PK | — |
| value | TEXT | NOT NULL | — |
| updated_at | TIMESTAMPTZ | — | NOW() |

Known keys: `TRADING_ENABLED`, `TRADING_MAX_SIZE`, `TRADING_MAX_DAILY_LOSS`, `ENABLED_STATIONS`, `AUTH_PASSWORD`

### auth_sessions

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| id | SERIAL | PK | auto |
| token_hash | VARCHAR(128) | NOT NULL | SHA-256 |
| expires_at | TIMESTAMPTZ | NOT NULL | — |
| revoked | BOOLEAN | — | false |
| created_at | TIMESTAMPTZ | — | NOW() |

---

## 2. Jonah DB (`jonah_prod`)

Schema: `wbot-jonah/src/db.py` (raw SQL, psycopg2)

### metar_readings

| Column | Type | Nullable | Default | Source |
|--------|------|----------|---------|--------|
| id | SERIAL | PK | auto | — |
| station | VARCHAR(4) | NOT NULL | — | Ruth: `station` |
| temp_c | REAL | YES | — | Ruth: `tempC` |
| dewpoint_c | REAL | YES | — | Ruth: `dewpointC` |
| humidity_pct | SMALLINT | YES | — | Ruth: `humidityPct` |
| wind_deg | SMALLINT | YES | — | Ruth: `windDeg` |
| wind_kt | SMALLINT | YES | — | Ruth: `windKt` |
| gust_kt | SMALLINT | YES | — | Ruth: `gustKt` |
| visibility_m | INT | YES | — | Ruth: `visibilityM` |
| cloud_layers | JSONB | YES | — | Ruth: `cloudLayers` |
| pressure_hpa | REAL | YES | — | Ruth: `pressureHpa` |
| metar_raw | TEXT | YES | — | Ruth: `metarRaw` |
| max_temp_c_6h | REAL | YES | — | Ruth: `maxTempC6h` |
| valid_utc | TIMESTAMPTZ | YES | — | Ruth: `validUtc` |
| captured_at | TIMESTAMPTZ | — | NOW() | — |

Indexes: `(station, captured_at)`

**Dedup rule:** Only saves when `metarRaw` content changes (main.py line 236).

### pws_readings

| Column | Type | Nullable | Default | Source |
|--------|------|----------|---------|--------|
| id | SERIAL | PK | auto | — |
| station | VARCHAR(4) | NOT NULL | — | Ruth: `station` |
| median_c | REAL | YES | — | Calculated: median(tempF→°C) |
| reading_count | SMALLINT | YES | — | `len(readings)` |
| solar_radiation | REAL | YES | — | `max(readings[].solarRadiation)` |
| uv | REAL | YES | — | `max(readings[].uv)` |
| raw_readings | JSONB | YES | — | Full readings array |
| captured_at | TIMESTAMPTZ | — | NOW() | — |

Indexes: `(station, captured_at)`

**Throttle:** Saves every 5min (normal) or 1min (near peak).

### day_sessions

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| id | SERIAL | PK | auto |
| station | VARCHAR(4) | NOT NULL | — |
| date | DATE | NOT NULL | — |
| dawn_bucket | VARCHAR(20) | YES | — |
| dawn_confidence | REAL | YES | — |
| dawn_reasoning | TEXT | YES | — |
| current_bucket | VARCHAR(20) | YES | — |
| current_confidence | REAL | YES | — |
| current_reasoning | TEXT | YES | — |
| status | VARCHAR(10) | — | 'active' |
| timing | VARCHAR(10) | — | 'WAIT' |
| range_prob | REAL | YES | — |
| forecast_max | REAL | YES | — |
| created_at | TIMESTAMPTZ | — | NOW() |
| locked_at | TIMESTAMPTZ | YES | — |
| resolved_at | TIMESTAMPTZ | YES | — |

**UNIQUE:** (station, date)

### session_updates

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| id | SERIAL | PK | auto |
| session_id | INT | NOT NULL | FK → day_sessions(id) |
| phase | VARCHAR(10) | NOT NULL | dawn, update, rapid |
| bucket | VARCHAR(20) | YES | — |
| confidence | REAL | YES | — |
| timing | VARCHAR(10) | YES | WAIT, SMALL, MEDIUM, STRONG |
| reasoning | TEXT | YES | — |
| sources | JSONB | YES | EnsembleSignal.to_dict() |
| market_snapshot | JSONB | YES | — |
| metar_at_update | REAL | YES | Latest METAR temp °C |
| pws_at_update | REAL | YES | Latest PWS median °C |
| created_at | TIMESTAMPTZ | — | NOW() |

### learning_outcomes

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| id | SERIAL | PK | auto |
| station | VARCHAR(4) | NOT NULL | — |
| date | DATE | NOT NULL | — |
| actual_max_c | REAL | YES | From Wendy DB: MAX(metar_observations.temp_c) |
| actual_bucket | VARCHAR(20) | YES | Calculated from actual_max |
| dawn_bucket | VARCHAR(20) | YES | From day_sessions |
| final_bucket | VARCHAR(20) | YES | Last prediction |
| was_correct | BOOLEAN | YES | final == actual |
| error_value | REAL | YES | Degrees off |
| market_favorite_bucket | VARCHAR(20) | YES | Highest-odds bucket |
| market_was_correct | BOOLEAN | YES | — |
| jonah_beat_market | BOOLEAN | YES | — |
| sources_accuracy | JSONB | YES | {lgbm: -1.5, chronos: 0.2} |
| conditions | JSONB | YES | Weather conditions vector |
| evolution | JSONB | YES | [{phase, bucket, confidence}] |
| created_at | TIMESTAMPTZ | — | NOW() |

**UNIQUE:** (station, date)

**Cross-DB read:** Learning loop connects to Wendy's `wbot_prod` via `DATABASE_URL` to read `metar_observations.temp_c WHERE DATE(valid_utc) = yesterday`.

---

## 3. Qdrant Vector DB

Collection: `weather_days_v4`

| Property | Value |
|----------|-------|
| Dimensions | 8 |
| Distance | COSINE |
| Point ID | MD5(station:date)[:16] |

### Vector (8 dimensions, normalized)

| Index | Field | Normalization |
|-------|-------|--------------|
| 0 | temp_c | / 40 |
| 1 | humidity_pct | / 100 |
| 2 | wind_kt | min(val, 30) / 30 |
| 3 | hour_local | / 24 |
| 4 | month | / 12 |
| 5 | dewpoint_c | / 30 |
| 6 | gust_kt | min(val, 40) / 40 |
| 7 | station_hash | md5(station) % 100 / 100 |

### Payload

| Field | Type | Source |
|-------|------|--------|
| station | string | ICAO |
| date | string | YYYY-MM-DD |
| actual_max | float | learning_outcomes.actual_max_c |
| actual_bucket | string | Calculated |
| predicted_bucket | string | day_sessions.current_bucket |
| was_correct | bool | learning_outcomes.was_correct |
| confidence | float | day_sessions.current_confidence |
| error_value | float | Degrees off |
| evolution | list | [{phase, bucket, confidence}] |
| sources_accuracy | dict | Per-source error |

**Populated by:** `learning.py` nightly at 06:00 UTC.

---

## 4. API Contracts

### Ruth → Wendy/Jonah METAR Signal

```json
{
  "type": "METAR",
  "station": "KSEA",
  "tempC": 15.6,
  "tempF": 60,
  "dewpointC": 8.3,
  "humidityPct": 62,
  "windDeg": 210,
  "windKt": 12,
  "gustKt": null,
  "visibilityM": 16093,
  "cloudLayers": [{"cover": "FEW", "altFt": 2500}],
  "pressureHpa": 1013.2,
  "maxTempC6h": null,
  "minTempC6h": null,
  "seaLevelPressureHpa": 1015.0,
  "wxString": null,
  "autoStation": true,
  "metarType": "METAR",
  "metarRaw": "KSEA 281553Z 21012KT ...",
  "metarTime": "2026-03-28T15:53:00Z",
  "capturedAt": "2026-03-28T15:53:02Z",
  "traceId": "ruth-metar-KSEA-20260328-155302123"
}
```

### Jonah → Wendy Prediction

```json
{
  "station": "KSEA",
  "prediction": {
    "bucket": "58-59°F",
    "confidence": 0.72,
    "reasoning": "Range 58-59°F at 77%. Timing: MEDIUM. Sources: LightGBM, Chronos, Open-Meteo, RAG, GPT.",
    "predicted_at": "2026-03-28T18:00:00Z",
    "phase": "update"
  }
}
```

### Jonah → Wendy Trigger (NEW)

```json
{
  "station": "KSEA",
  "bucket": "58-59°F",
  "signal": "BUY",
  "confidence": 0.85,
  "reasoning": "ensemble consensus",
  "traceId": "jonah-trigger-KSEA-1711648800"
}
```

---

## 5. Known Issues (Fixed)

| Bug | Root Cause | Fix | Date |
|-----|-----------|-----|------|
| Jonah METARs never saved to DB | `body.get("raw")` — field is `metarRaw` | Changed to `body.get("metarRaw")` | 2026-03-28 |
| Sessions fail to save | `np.float64` not serializable by psycopg2 | `EnsembleSignal.__post_init__` converts to native float | 2026-03-28 |
| Learning loop fails | `DATE(observed_at)` — column is `valid_utc` | Changed to `DATE(valid_utc)` | 2026-03-28 |
| Qdrant empty | Learning loop never ran (upstream bugs) | Cascading fix from above 3 | 2026-03-28 |
