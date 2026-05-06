---
name: project_spread_v2
description: Spread shadow trader v2 (drop A entirely) and v2.5 (re-enable A on idx=-1 only) — paper-validated 60d backtest Apr+Feb-Mar 2026
type: project
originSessionId: f47c8c1a-4008-458c-a6f2-19b57e76725d
---

Spread shadow trader lives in `wbot-wendy/src/modules/spread/`. Active rule_set_version constant in `spread.types.ts`.

**v1** `spread-v1-2026-04-20`: A/B/C cascade. `combined = first_non_null(A, B, C)`.

**v2** `spread-v2-2026-04-27`: A disabled on all legs, hold to C. Drove from Apr in-sample backtest where pnl_C >= pnl_combined under every cohort filter — A locks +$15 but winning legs resolve at ~$40. Also added: `ask < $0.05` skip (`ask_too_low`), `SPREAD_DISABLED_STATIONS = {KORD, KAUS}`, `polymarket_market_trades` archive table + 24h snapshot job (outlasts CLOB ~30-day prices-history retention).

**v2.5** `spread-v2.5-2026-04-28`: A re-enabled BUT only when `bucket_index === -1` AND `rule_set_version === SPREAD_RULE_SET_VERSION`. Idx 0/+1 stay hold-to-C. Rationale: idx=-1 (lottery) usually loses C (~$10), so capping at +$15 with A captures the up-tick. Idx 0/+1 dominated by C on winners. 60d paper backtest filtered cohorts ($10 stake): HYBRID-1 +$1115 vs v2 C-only +$530, ~2x.

**Why:** User pushed back on v2 with "A tem 328 pq tirar?" — re-examined data and found per-idx breakdown: A wins on idx=-1 (+$159 of $223 total at $2 stake), C wins on idx 0/+1. Hybrid captures both. Confidence: paper-medido. Real A fill rate unknown — monitor 15min may miss spikes that backtest sees in trade-level peaks. Conservative estimate ~60% real fill → still nets ~$190 vs v2 $106 at $2 stake.

**How to apply:** Spread service uses single `SPREAD_RULE_SET_VERSION` constant — bumping it switches strategy for new cohorts only; old open rows keep their version (hard-gated in monitor). Backtest scripts in `/tmp/spread-bt/` (`real_backtest.py` Apr in-sample, `extended_v2.py` Feb-Mar OOS via trades endpoint). Never extend Exit A to idx 0/+1 without re-running per-idx backtest. Marty UI has version filter pill (`all/v1/v2/v2.5`) and pink badge for v2.5 cohorts.

**Sazonalidade descoberta (não validada em prod):**

- KSEA: positivo Apr 2026, negativo Feb-Mar 2026, 64% in-window May-Jun 2025. Provavelmente seasonal.
- Forecast bias FLIPS: −1.25°F Apr (over-predict) vs +1.05°F May-Jun 2025 (under-predict). Idx ótimo pode mudar com estação. May-Jun 2025 climate-only analysis: 49% in-window hit vs 58% Apr.
