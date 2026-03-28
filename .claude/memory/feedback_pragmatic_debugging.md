---
name: feedback_pragmatic_debugging
description: Debug by following the user's hypothesis first, not jumping to infrastructure assumptions
type: feedback
---

When debugging, follow the user's description of symptoms literally before investigating infrastructure.

**Why:** User said "stopped after entering a position" — the correct first check was Wendy's signal processing flow after a trade, not Ruth's NOAA endpoint or dedup logic. Spent 30+ minutes on Ruth (wrong endpoint, revert, dedup analysis) when the bug was a simple `return` in Wendy that skipped DB writes when market was resolved.

**How to apply:**
1. When user describes a symptom tied to a state change ("stopped after X"), trace the code path that X triggers
2. Check the simplest explanation first: did the code explicitly skip/return somewhere?
3. Don't assume infrastructure failure — verify the data flow end-to-end (Ruth sent → Wendy received → DB wrote) before diving into any single component
4. Be pragmatic: if Ruth logs say "sent 8 METARs" but DB shows 5, the problem is between Ruth and DB (Wendy), not in Ruth
