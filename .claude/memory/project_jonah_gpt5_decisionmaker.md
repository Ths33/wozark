---
name: project_jonah_gpt5_decisionmaker
description: Jonah V5 architecture as of 2026-04-03 — GPT-5 decision-maker, pre-METAR predictions, intraday drift learning, heartbeat, manual isolation
type: project
---

# Jonah V5 — Current Architecture (2026-04-03)

## GPT-5 as Final Decision-Maker
- Receives ALL raw data: METAR history, PWS readings, solar/UV, temperature slopes, all 4 model outputs, running max, station context, NWS grid forecasts
- Its bucket + timing output OVERRIDES the ensemble result
- Output canonicalized to valid even-odd market buckets (two-stage: GPT output cleaning + market normalization)
- If GPT-5 fails, ensemble result is used as fallback
- Config: max_completion_tokens=16384, response_format=json_object, 60s timeout
- Constrained to valid_buckets list built from ensemble probability distribution

## METAR-Driven 55min Prediction Cycle
- Each METAR arrival resets a 55min per-station timer
- When timer fires: full ensemble (parallel) + GPT-5 → floor check → push to Wendy
- Persisted across restarts via `_restore_pre_metar_state()`
- station_check cron handles dawn detection only

## Pre-METAR Predictions
- Fires ~5min before predicted next METAR
- Uses PWS gap (×0.7) + 15min slope (×5min extrapolation) to predict bucket cross
- Records BOTH crossing and non-crossing evaluations (for learning)
- Confidence: gap strength (max 0.4) + slope (max 0.2) + reliability bonus (0.1)
- Fires trigger if MEDIUM/STRONG and crosses bucket
- Saved to session_updates with phase="pre_metar"

## Intraday Learning (RAG)
- Nightly learning loop (06:00 UTC): compares predictions vs actuals
- **Intraday drift detection**: tracks when early-correct predictions later drift wrong
  - Metrics: had_correct_window, drift_count, recovered_after_drift, max_abs_error_after_correct
  - PWS gap jumps and METAR movement at drift onset captured
- **Per-source error tracking**: LightGBM, Chronos, Open-Meteo, RAG errors per day
- **Pre-METAR accuracy**: evaluates pre-METAR calls against actual max
- All stored in Qdrant (weather_days_v5, 12-dim vectors) + learning_outcomes table
- RAG retrieves similar historical days with drift warnings for GPT context

## Heartbeat System
- GET /predictions/{station} includes heartbeat: status (healthy/waiting/stale/missing)
- Shows: last prediction time, METAR cadence, next cycle countdown, execution mode
- Manual updates filtered from scheduled metrics (phase != "manual")

## Manual Run Isolation
- POST /predict/{station} accepts optional running_max_c + current_temp_c
- Saves as phase="manual", does NOT update scheduled state (day_sessions)
- Wendy sends observed temps when proxying manual runs from Marty

## Learning Endpoints
- GET /learning/metrics — accuracy, source errors, daily stats, RAG point count
- GET /learning/debug — per-date resolution diagnostics (detects UTC/local mismatches)
- POST /admin/learning — manual trigger for specific target_date

## Wendy Integration
- METAR now observe-only: Wendy logs threshold crossing but waits for Jonah pre_metar confirmation
- metarTradingEnabled flag gates METAR autonomous trading
- Bucket labels canonicalized (Wendy normalizes Jonah's output to even-odd°F format)
- Phase mapping: dawn→briefing, update→peak_update
- 95%+ confidence triggers bypass early trading window

## Exit Logic
- Tracks triggered BUYs per station in `_last_triggers`
- If bucket's range_prob drops below 20% → fires SELL trigger
- Persisted to trigger_history table, restored on restart
