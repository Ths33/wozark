# Wozark migration runbook — 2026-05-06

## Backup contents

| Item                                          | Path                                             | Size   | Status       |
| --------------------------------------------- | ------------------------------------------------ | ------ | ------------ |
| Wendy DB (Postgres custom dump, level 9 zstd) | `wendy_wbot_prod.dump`                           | 9.4 MB | done         |
| Jonah DB (Postgres custom dump, level 9 zstd) | `jonah_jonah_prod.dump`                          | 8.9 MB | done         |
| Wendy schema-only SQL                         | `wendy_schema.sql`                               | 17 KB  | done         |
| Jonah schema-only SQL                         | `jonah_schema.sql`                               | 15 KB  | done         |
| Code (5 repos)                                | github.com/Ths33/{wendy,marty,jonah,ruth,wozark} | n/a    | pushed       |
| Qdrant `weather_days_v5` collection           | **TODO** — see below                             | n/a    | pending user |

Compressed bundle: `wozark_backup_2026-05-06_partial.tar.gz` (everything above).

## Qdrant snapshot — manual step required

Qdrant port 6333 is not exposed externally. You must run the snapshot command from the server (CapRover host shell or web terminal).

### Option A — Qdrant snapshot API (preferred, atomic per collection)

```bash
# 1. Create snapshot
docker exec srv-captain--qdrant \
  curl -s -X POST http://localhost:6333/collections/weather_days_v5/snapshots

# 2. List to get the generated snapshot filename
docker exec srv-captain--qdrant \
  curl -s http://localhost:6333/collections/weather_days_v5/snapshots

# 3. Copy the .snapshot file out
SNAP=$(docker exec srv-captain--qdrant \
  ls /qdrant/storage/snapshots/weather_days_v5/ | tail -1)
docker cp srv-captain--qdrant:/qdrant/storage/snapshots/weather_days_v5/$SNAP \
  ./qdrant_$SNAP
```

### Option B — full storage tarball (fallback, larger)

```bash
docker exec srv-captain--qdrant \
  tar -czf /tmp/qdrant_storage_2026-05-06.tar.gz -C /qdrant storage
docker cp srv-captain--qdrant:/tmp/qdrant_storage_2026-05-06.tar.gz \
  ./qdrant_storage_2026-05-06.tar.gz
```

Download to your laptop with `scp <server>:./qdrant_*.* .` or via the CapRover file browser.

## Restore on new server

### 1. Postgres

```bash
# Wendy
createdb -h <new-host> -U postgres wbot_prod
PGPASSWORD=<pw> pg_restore -h <new-host> -U postgres -d wbot_prod \
  --clean --if-exists --no-owner wendy_wbot_prod.dump

# Jonah
createdb -h <new-host> -U postgres jonah_prod
PGPASSWORD=<pw> pg_restore -h <new-host> -U postgres -d jonah_prod \
  --clean --if-exists --no-owner jonah_jonah_prod.dump
```

Verify row counts after restore:

```sql
-- Wendy
SELECT count(*) FROM trades;
SELECT count(*) FROM spread_shadow_trades;
SELECT count(*) FROM metar_observations;
SELECT count(*) FROM polymarket_market_trades;

-- Jonah
SELECT count(*) FROM learning_outcomes;
SELECT count(*) FROM metar_readings;
SELECT count(*) FROM session_updates;
```

### 2. Qdrant

Recreate Qdrant container, then restore the collection from snapshot:

```bash
# Copy snapshot into the new Qdrant container
docker cp qdrant_<filename>.snapshot \
  srv-captain--qdrant:/qdrant/storage/snapshots/weather_days_v5/

# Trigger recovery
docker exec srv-captain--qdrant \
  curl -X PUT http://localhost:6333/collections/weather_days_v5/snapshots/recover \
  -H 'Content-Type: application/json' \
  -d '{"location": "file:///qdrant/storage/snapshots/weather_days_v5/<filename>.snapshot"}'
```

Verify:

```bash
docker exec srv-captain--qdrant \
  curl -s http://localhost:6333/collections/weather_days_v5 | jq .result.points_count
```

### 3. Code

CapRover apps deploy via `git push` to each app's git remote. All 5 repos already on github — point CapRover at them and push (or use Captain's "Deploy from github" UI).

Required env vars (from each project's CLAUDE.md):

- Wendy: `DATABASE_URL`, `RUTH_SECRET`, `POLY_*`, `JWT_SECRET`, `JONAH_URL`, `MARTY_ORIGIN`
- Jonah: `JONAH_DATABASE_URL`, `DATABASE_URL` (Wendy read), `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `RUTH_SECRET`, `WENDY_URL`, `QDRANT_HOST`, `QDRANT_PORT`, `WEIGHT_*`, `NOAA_CDO_TOKEN`
- Ruth: `WENDY_URL`, `JONAH_URL`, `RUTH_SECRET`, `SYNOPTIC_TOKEN`
- Marty: `NEXT_PUBLIC_WENDY_URL`, `NEXT_PUBLIC_WENDY_WS_URL`

### 4. Smoke test

1. `GET wendy.wozark.com/health` → expect `{ ok: true }`
2. `GET wendy.wozark.com/spread/summary` (with JWT) → expect non-empty totals matching pre-migration counts
3. Wait for next scan window (01:00-03:00 BRT) → confirm a new v3 cohort row appears
4. `GET marty.wozark.com/spread` in browser → confirm cohorts render with v3 green badge

## Schedule

Migration window: ideal during Polymarket low-activity hours (~04:00-06:00 BRT — after spread scan, before peak trading) to minimize trade-window misses.

Critical: skipping a v3 scan window (01:00-03:00 BRT) means losing one day of D+2 cohort entries. Plan the cutover to either complete before 01:00 BRT or after 03:00 BRT.
