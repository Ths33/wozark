---
name: Nunca usar harvest NO / BUY NO
description: BUY NO foi removido da Wendy. É tiro no pé — não reintroduzir nem modelar em backtest/análise como "recovery".
type: project
originSessionId: 54765d79-9fc7-4875-ad6e-18a50dbd3ce1
---

**Regra hard**: Wendy não faz BUY NO (harvest NO). Foi removido do stack por decisão do Tales — considerado foot-gun. Não deve ser reintroduzido.

**Why:** Harvest NO parecia "recovery grátis" no rotate, mas em prática (a) preços NO refletem mesma info do YES, não há edge adicional; (b) dobra exposição ao mesmo evento em direções opostas, complicando contabilidade; (c) mistura incentivos — se acertamos YES novo, o NO velho vira perda; (d) taxas e slippage consomem o "recovery" quase todo.

**How to apply:**

- Ao propor solução de ROTATE recovery: usar apenas SELL do bucket antigo no live bid. Nunca BUY NO.
- Backtest: modelar recuperação via SELL only (coarse mas honesto), não via NO harvest
- Se um agente ou linguagem referenciar `harvest`, `BUY NO`, `buy_no`, remover/reescrever
- Módulo `harvest` não existe mais em `wbot-wendy/src/modules/` — não recriar
