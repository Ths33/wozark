---
name: feedback_trading_disabled_means_all
description: When trading is disabled, ALL automated operations must stop — monitor sells, retries, rotates, everything
type: feedback
---

When tradingEnabled=false, NO automated buy OR sell must execute. Period.

**Why:** The monitor service was selling user's manual positions even with trading disabled. It ran checkDuplicatePositions() and processSellRetries() without checking the flag. User lost real money.

**How to apply:** Every code path that places ANY order (buy, sell, rotate, retry, monitor cleanup) must check tradingEnabled first. There is no exception. If trading is off, the system is read-only — it receives data, logs, broadcasts, but never touches the CLOB.
