---
name: TGFTP é arquivo estático, sem rate limit
description: https://tgftp.nws.noaa.gov/data/observations/metar/stations/*.TXT é texto estático cacheado globalmente. Não tem rate limit. Não propor proteção.
type: reference
originSessionId: 54765d79-9fc7-4875-ad6e-18a50dbd3ce1
---

TGFTP (`tgftp.nws.noaa.gov/data/observations/metar/stations/{ICAO}.TXT`) serve arquivos de texto estáticos com o último METAR por estação, atualizados pela NOAA. São servidos via CDN/cache global, dimensionados pra throughput massivo.

**Why:** Propor "proteção contra rate limit" em qualquer fetch TGFTP é over-engineering. O endpoint é estático, não limita. Se houver erro de rede, é falha transitória comum, não rate.

**How to apply:**

- Não sugerir throttle, backoff específico, ou lógica "rate-limit detected" pra TGFTP
- Alguns requests/minuto por 10 stations × poll denso = zero risco
- Synoptic SIM tem rate limit (API com tokens). TGFTP NÃO
