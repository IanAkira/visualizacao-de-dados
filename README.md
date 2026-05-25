# Visualização de Dados — Mercado de Trabalho na Era da IA

Painel analítico construído a partir do **AI Job Trends Dataset** (30.000 ocupações, 8 setores, 8 países).
- Link dos dados: https://www.kaggle.com/datasets/sahilislam007/ai-impact-on-job-market-20242030

## Acesso
- Página pública: https://ianakira.github.io/visualizacao-de-dados/

## O que tem no painel
- 4 KPIs (salário médio, risco de automação, trabalho remoto, crescimento 2024 → 2030)
- 12 gráficos Chart.js cobrindo salários, escolaridade, status, impacto da IA, geografia e distribuições
- 4 rankings: cargos mais bem pagos, mais automatizáveis, em maior crescimento e mais frequentes

## Estrutura
- `index.html` — o painel
- `data.js` / `data.json` — dataset agregado (gerado por `aggregate.ps1`)
- `aggregate.ps1` — script PowerShell que processa CSVs em lote e mantém estado incremental

