---
name: Read code before describing active behavior
description: Never describe system behavior from CLAUDE.md alone — confirm in source code first
type: feedback
originSessionId: 54765d79-9fc7-4875-ad6e-18a50dbd3ce1
---

Before describing what the system does (signal flow, trade logic, any active behavior), ALWAYS read the actual source code. Do not rely on CLAUDE.md, README, or docs as source of truth for current behavior — they frequently lag behind the code.

**Why**: In 2026-04-14, I (Claude) described the signal flow to Tales based on an outdated CLAUDE.md that still showed Jonah firing /trigger and PWS going to Wendy. Neither was true — `TRIGGER_ENABLED = False` hardcoded in proxy.py for 2 days, PWS flow to Wendy removed. Tales was justifiably upset: "vc anda mal projetando as coisas... agora eu não sei se acredito em vc". Trust damage was real.

**How to apply**:

1. When user asks "how does X work now?" → grep/read the active code path first, then describe.
2. When describing a signal flow, trade path, or "what the system does" → cite file:line from code, not docs.
3. When docs say X and code says Y → code wins. Flag the stale doc, don't propagate the lie.
4. When taking over a project with stale docs → update the docs as you discover discrepancies, don't use them as if current.
5. Before answering a user question about active behavior, at minimum grep the relevant flag/function to confirm it still does what docs claim.
