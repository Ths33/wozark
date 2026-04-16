---
name: Jonah tem dados históricos para backtest
description: Jonah armazena observações METAR + predições + outcomes. Usar pra backtest de mudanças na Wendy, não pedir dataset novo.
type: reference
originSessionId: 54765d79-9fc7-4875-ad6e-18a50dbd3ce1
---

Jonah (wbot-jonah) já acumula:

- Observações METAR recebidas de Ruth (temp, T-group quando presente, timestamps)
- Predições feitas pelo ensemble (LightGBM, Chronos, Open-Meteo, RAG/Qdrant)
- Outcomes resolvidos (o que efetivamente foi o max daily)

**Why:** Meses de dados prontos pra backtest. Não precisamos criar pipeline novo de histórico — usar o que Jonah já tem.

**How to apply:** Ao propor backtest framework, primeiro ler o schema de Jonah (postgres dele + Qdrant) e reusar os dados. Simulação de decisões pode rodar em Python ao lado do Jonah, lendo do mesmo DB.
