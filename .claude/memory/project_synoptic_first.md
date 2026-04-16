---
name: Synoptic-first edge — fresh sensor readings, not hourly METAR
description: Ruth uses Synoptic air_temp 5-min sensor readings to trigger trades BEFORE official hourly METAR confirms — that IS the edge
type: project
originSessionId: 54765d79-9fc7-4875-ad6e-18a50dbd3ce1
---

**The edge:** stations report sensor data continuously (~5min granularity for ASOS). Synoptic exposes those fresh readings via `air_temp_set_1` etc. The official METAR only publishes once per hour (~:53). Bots that depend on the hourly METAR (TGFTP, NOAA cycles) see the new daily max ~30-50min late on average.

**Wozark's strategy:** Ruth polls Synoptic every 5min, treats each fresh sensor reading as authoritative, advances runningMaxC, fires BUY immediately when threshold crosses. This captures the new high BEFORE the hourly METAR confirms — same as the bots already winning on these markets.

**What Ruth must do** (poller.rs:228+):

- Always use `reading.temp_c` (latest air_temp from Synoptic) as signal.tempC
- Always use `reading.obs_time` (latest sensor timestamp) as signal.metar_time / validUtc
- Never let `parse_metar(raw)` overwrite temp/timestamp — that uses the stale hourly METAR values
- The METAR raw string is only good for enriching cloud_layers / visibility / sea_level_pressure (fields not in Synoptic's direct vars)
- Other direct vars (dewpoint, wind, pressure/altimeter, ceiling, weather_condition) come fresh from Synoptic

**What I got wrong on 2026-04-15 (corrected):**

- I described Wendy "trading on METAR threshold crossings" as if METAR meant the hourly publication. Wrong. METAR here means "any signal from Ruth", which is now the fresh Synoptic sensor reading.
- I explained lag like "we trade at :58 because METAR publishes at :53". Wrong. We should trade at :10:02 if the sensor reads the new high at :10.
- I introduced the bug where Ruth preferred parse_metar over fresh sensor data when metar_set_1 was present. Caused effectively zero edge over TGFTP. Fixed in commit 5804580.

**How to apply:**

- Trade triggers fire on EVERY new Synoptic reading where bucket changes — not waiting for hourly METAR
- A new daily high detected at :15 means the trade fires at :15:01-:15:05, not :53+
- TGFTP fallback only matters when Synoptic is fully down
- Tales already understands this deeply — don't second-guess; verify code matches the model

**TGFTP delay (for context):** TGFTP cycle files = ~3min from station to TXT publish + ~2min for TXT to refresh = 5min total. Synoptic exposes the same data within seconds-to-1min. Edge over TGFTP-only bots = 5-30+ min depending on when in the hour the new max occurs.
