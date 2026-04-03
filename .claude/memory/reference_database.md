---
name: reference_database
description: External database connection for querying logs, trades, triggers, and config directly from dev machine
type: reference
---

Production PostgreSQL (externally accessible):
`postgresql://postgres:92b2602fbd1205f5@45.93.138.190:15432/wbot_prod`

Tables: metar_observations, pws_observations, trades, logs, app_config, auth_sessions, jonah_triggers

- `jonah_triggers`: every Jonah trigger attempt (executed/blocked/no_payload/failed) with confidence, timing, currentTempF, outcome, blockReason. Added 2026-03-30 for accuracy analysis.

Use this to pull logs, check trades, debug issues — no need to authenticate via Wendy API.
