---
name: feedback_no_untested_changes
description: Never change working CLOB/trading code based on external references without verifying against v4 behavior first
type: feedback
---

Do not modify working trading code (CLOB client, order params, signature types) based on external skill references or documentation alone. The v4 codebase is the proven reference.

**Why:** Changed signature_type 2→1 and price 0.75→actual based on skill docs, both broke trading. V4 uses signature_type=2 and price:0.75 ceiling — both are correct despite conflicting with external docs. The JS SDK numbering differs from the EIP-712 spec.

**How to apply:** Before changing any CLOB parameters, verify v4 uses the same value. If v4 works with a value, keep it. Only change if there's a concrete bug, not to "align with docs".
