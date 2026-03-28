---
name: feedback_single_instance
description: Never run two Wendy instances with the same POLY credentials — causes duplicate trades and unauthorized sells
type: feedback
---

Only ONE Wendy instance can run with a given set of POLY_* credentials at a time.

**Why:** User had an old Wendy instance running elsewhere with the same POLY_API_KEY/POLY_PRIVATE_KEY. The old monitor service was selling positions that the user bought manually, causing real financial losses. No logs appeared in the current Wendy because the trades came from the other instance.

**How to apply:** Before deploying a new Wendy instance, ensure no other instance shares the same credentials. If migrating, stop the old instance FIRST. Consider adding a startup check that verifies no other instance is active (e.g., a heartbeat mechanism or unique instance ID logged to DB).
