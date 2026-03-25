---
name: feedback_monitor_duplicates
description: Monitor must group by tokenId not station — different buckets on same station are valid positions
type: feedback
---

Monitor duplicate detection must group by `station:tokenId`, not just `station`. Multiple positions on the same station in different buckets (e.g. 5°C + 6°C) are intentional, not duplicates.

**Why:** The original logic grouped by station only, causing the monitor to sell valid positions in different buckets. This caused real trading losses when the user manually entered a position and the monitor sold it 3 minutes later.

**How to apply:** When writing position management code, always consider that a station can legitimately hold multiple positions in different buckets. Also: terminal CLOB errors ("not enough balance/allowance") must stop retry immediately — don't keep trying to sell positions that no longer exist.
