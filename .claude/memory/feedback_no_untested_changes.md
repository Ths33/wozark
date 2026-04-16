---
name: Always build before pushing
description: Run build/compile before every push — never push untested code
type: feedback
originSessionId: 6fbec674-b981-4501-b7e4-315eaee889f9
---

Always run `cargo build` (Ruth), `npm run build` (Wendy/Marty), before pushing. Fix compile errors first.

**Why:** Pushing broken code causes CapRover deploy failures that require another push cycle.
**How to apply:** After making changes to any service, run the build command and verify it succeeds before git push.
