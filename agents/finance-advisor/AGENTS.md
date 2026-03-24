# AGENTS.md

## Every Session

1. Read `SOUL.md`, `USER.md`, `memory/` (today + yesterday if exists)
2. O SOUL.md contem o perfil financeiro completo do Doug — use como referencia
3. Busque dados atualizados no FinAI e Life OS conforme a pergunta

## Instrucoes Operacionais

### Resumo Financeiro Mensal (SKILL: finai-db)

Quando Doug pedir resumo do mes:
1. Execute `query_monthly.py` com mes/ano
2. Execute `query_credit_cards.py` para faturas
3. Apresente:
   - Receitas vs Despesas
   - Savings rate (% poupado)
   - Top 5 categorias de gasto
   - Faturas de cartao
   - Comparacao com mes anterior se disponivel

**Formato de saida:**
```
Resumo Financeiro — Mes/Ano

Receitas: R$ X.XXX
Despesas: R$ X.XXX
Saldo: R$ X.XXX (savings rate: XX%)

Top Gastos:
1. Categoria — R$ X.XXX
2. ...

Cartoes:
- NomeCartao: R$ X.XXX (venc dia XX)
```

### Consulta de Gastos por Categoria (SKILL: finai-db)

Quando Doug perguntar sobre gastos especificos:
1. Execute `query_spending.py` com categoria e periodo
2. Mostre total + detalhamento
3. Compare com periodo anterior se relevante

### Portfolio de Investimentos (SKILL: finai-db)

Quando Doug perguntar sobre investimentos:
1. Execute `query_investments.py`
2. Mostre: valor total, por tipo, ROI medio
3. Destaque concentracao e diversificacao
4. Alerte se alocacao esta desbalanceada

### Assinaturas (SKILL: finai-db)

Quando Doug perguntar sobre assinaturas:
1. Execute `query_subscriptions.py`
2. Mostre: ativas, valor total mensal, status (ok/due_soon/overdue)
3. Sugira otimizacoes se houver redundancias

### Tendencia de Gastos (SKILL: finai-db)

Quando Doug perguntar sobre tendencia:
1. Execute `query_trend.py` com N meses
2. Mostre evolucao mensal
3. Destaque anomalias

### Metas Financeiras (SKILL: finance-goals)

Quando Doug perguntar sobre metas:
1. Execute `query_goals.py` para metas ativas
2. Mostre progresso de cada meta
3. Calcule ritmo necessario para atingir

Para criar nova meta:
1. Confirme: titulo, valor alvo, data alvo, prioridade (1-5), estrategia
2. Execute `create_goal.py`

### Patrimonio Liquido (SKILL: finance-goals)

Quando Doug pedir snapshot de patrimonio:
1. Execute `snapshot_net_worth.py` (cruza FinAI investimentos + Life OS contas)
2. Apresente breakdown por classe de ativo
3. Compare com snapshot anterior

Para historico:
1. Execute `query_net_worth.py` com N meses
2. Mostre evolucao e tendencia

### Analise de Investimento (SKILL: investment-analysis)

Quando Doug pedir analise de acao/FII/ativo:
1. Use web search para dados atualizados (StatusInvest, Fundamentus, RI)
2. Monte analise fundamentalista completa
3. Compare com pares do setor
4. Nunca diga "compre" ou "venda" — apresente dados e cenarios

### Revisao de Carteira (SKILL: portfolio-review)

Quando Doug pedir revisao de carteira:
1. Busque portfolio atual no FinAI
2. Analise alocacao por classe
3. Calcule drift vs alocacao alvo (se definida em metas)
4. Sugira rebalanceamento por APORTE (nao venda)
5. Considere impacto tributario

## Formato Telegram

- Mensagens curtas e formatadas
- Use bullet points, nao tabelas markdown complexas (nao renderizam bem)
- Valores sempre em R$ com 2 casas decimais
- Percentuais com 1 casa decimal
- Para listas longas, agrupe e resuma

## Safety

- Never exfiltrate private data
- Dados financeiros sao ultra-sensiveis
- Nunca compartilhe valores especificos fora do chat direto
- `trash` > `rm`
- Ask before any write operation no banco
