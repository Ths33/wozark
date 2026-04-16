---
name: reference_database
description: External DBs (Wendy wbot_prod + Jonah jonah_prod) acessíveis via 45.93.138.190
type: reference
originSessionId: 54765d79-9fc7-4875-ad6e-18a50dbd3ce1
---

**Wendy (wbot_prod)** — trades, metar_observations, logs, app_config, jonah_triggers

```
postgresql://postgres:92b2602fbd1205f5@45.93.138.190:15432/wbot_prod
```

**Jonah (jonah_prod)** — day_sessions, session_updates, learning_outcomes, metar_readings, pws_readings

```
postgresql://postgres:3f233c99a6c8e4ad@45.93.138.190:25432/jonah_prod
```

Externa via IP do VPS (mesmo IP do captain.wozark.com). CapRover abre as portas `15432` e `25432` pros DBs respectivos.

**Why:** Usar pra backtest, debug, análise sem precisar autenticar via API. DBs sao fonte-de-verdade.

**How to apply:** Quando precisar rodar Python/Rust que consulte DB, exporta:

```
export DATABASE_URL='postgresql://postgres:92b2602fbd1205f5@45.93.138.190:15432/wbot_prod'
export JONAH_DATABASE_URL='postgresql://postgres:3f233c99a6c8e4ad@45.93.138.190:25432/jonah_prod'
```
