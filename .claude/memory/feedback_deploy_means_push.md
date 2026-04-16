---
name: Deploy = git push
description: When user says "deploy", it always means git push to CapRover via main branch
type: feedback
originSessionId: 6fbec674-b981-4501-b7e4-315eaee889f9
---

"Deploy" always means `git push origin main` — CapRover auto-deploys on push.

**Why:** CapRover watches main branch and rebuilds Docker image automatically.
**How to apply:** After committing, push to origin main for each affected project. No manual CapRover UI steps needed.
