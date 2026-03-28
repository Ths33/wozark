---
name: feedback_realtime_not_polling
description: Never use polling/auto-refresh as substitute for real WebSocket reactivity. User considers this dishonest.
type: feedback
---

Auto-refresh polling (e.g. 30s interval refetch) is unacceptable as a substitute for real-time WS push. User considers it a "gambiarra" and fake streaming.

**Why:** After a full day requesting real-time data, the dashboard still had static market prices and positions that only updated on page reload or polling intervals. User feels deceived — the WS infrastructure exists but only covers METAR/PWS/logs, not the data that matters for trading decisions (prices, positions, P&L).

**How to apply:** If data changes server-side and the user needs to see it, it MUST be broadcast via WebSocket. Never substitute with setInterval polling. If the WS broadcast doesn't exist yet, say so honestly and implement it — don't paper over it with polling. This applies to all Marty real-time features. Market prices, positions, and P&L are the highest-priority items still missing WS push from Wendy.
