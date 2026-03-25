---
name: reference_database
description: External database connection for querying logs, trades, and config directly from dev machine
type: reference
---

Production PostgreSQL (externally accessible):
`postgresql://postgres:92b2602fbd1205f5@45.93.138.190:15432/wbot_prod`

Tables: metar_observations, trades, logs, app_config, auth_sessions

Use this to pull logs, check trades, debug issues — no need to authenticate via Wendy API.
