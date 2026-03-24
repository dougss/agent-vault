# Skill: finai-db

Acesso ao banco de dados do FinAI (Supabase PostgreSQL) para consultas financeiras.

## Conexao

Container: `finai-db-1` | User: `postgres` (superuser, bypassa RLS)
User ID do Doug: variavel `FINAI_USER_ID` em `~/.openclaw/secrets/.env`

## Scripts Disponiveis

### db_finai.py (modulo compartilhado)
Modulo de conexao. Importado pelos outros scripts. Nao executar diretamente.

### query_monthly.py — Resumo Mensal
```bash
python3 scripts/query_monthly.py [YYYY-MM]
# Default: mes atual
# Output JSON: {revenues, expenses, balance, savings_rate, top_categories: [{name, total}]}
```

### query_spending.py — Gastos por Categoria
```bash
python3 scripts/query_spending.py [--category "Nome"] [--start YYYY-MM-DD] [--end YYYY-MM-DD]
# Sem categoria: todas. Sem datas: mes atual.
# Output JSON: {period, total, categories: [{name, total, count, transactions: [{name, value, date}]}]}
```

### query_credit_cards.py — Cartoes e Faturas
```bash
python3 scripts/query_credit_cards.py [YYYY-MM]
# Default: mes atual
# Output JSON: {cards: [{name, due_day, invoice_amount, paid}]}
```

### query_investments.py — Portfolio
```bash
python3 scripts/query_investments.py
# Output JSON: {total_value, total_invested, avg_roi, total_contributions, total_returns, by_type: [{type, count, value, roi}], details: [{name, type, institution, initial, current, roi}]}
```

### query_subscriptions.py — Assinaturas
```bash
python3 scripts/query_subscriptions.py
# Output JSON: {active_count, monthly_total, subscriptions: [{name, amount, frequency, card, category, status}]}
```

### query_trend.py — Tendencia de Gastos
```bash
python3 scripts/query_trend.py [--months N]
# Default: 6 meses
# Output JSON: {months: [{month, revenues, expenses, balance, savings_rate}]}
```

## Notas
- Todos os scripts retornam JSON para facil parsing
- RLS e bypassado via user postgres — sempre filtre por user_id
- Valores em BRL (numeric 10,2)
- Datas no formato YYYY-MM-DD
