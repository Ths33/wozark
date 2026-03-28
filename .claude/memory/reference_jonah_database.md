---
name: reference_jonah_database
description: Jonah's own PostgreSQL database connection details (separate from Wendy's wbot-db)
type: reference
---

Jonah DB (read/write — sessions, observations, learning):
`postgresql://postgres:3f233c99a6c8e4ad@srv-captain--jonah-db:5432/jonah_prod`

External access: `postgres@45.93.138.190:25432/jonah_prod` (password: 3f233c99a6c8e4ad)

Tables: day_sessions, session_updates, day_buffer, learning_outcomes, metar_readings, pws_readings

Note: DB was created on 2026-03-26. Before this date, all Jonah data was in memory only.
