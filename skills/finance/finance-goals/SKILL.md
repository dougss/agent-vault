# Skill: finance-goals

Gerenciamento de metas financeiras e patrimonio liquido via Life OS PostgreSQL.

## Conexao

Container: `postgres` | User: `life_os` | DB: `life_os`
Senha: variavel `LIFE_OS_DB_PASS` em `~/.openclaw/secrets/.env`
User ID: `00000000-0000-0000-0000-000000000001` (default Life OS)

## Scripts Disponiveis

### db_lifeos.py (modulo compartilhado)
Modulo de conexao. Importado pelos outros scripts.

### create_goal.py — Criar Meta Financeira
```bash
python3 scripts/create_goal.py '{"title": "Reserva emergencia", "target_amount": 50000, "target_date": "2026-12-31", "priority": 1, "strategy": "R$2k/mes em CDB liquidez diaria"}'
# Campos obrigatorios: title, target_amount
# Opcionais: target_date, priority (1-5, default 1), strategy
```

### query_goals.py — Consultar Metas
```bash
python3 scripts/query_goals.py [--status active|completed|paused|cancelled]
# Default: active
# Output JSON: {goals: [{title, target, current, progress_pct, target_date, priority, strategy, status}]}
```

### snapshot_net_worth.py — Snapshot de Patrimonio
```bash
python3 scripts/snapshot_net_worth.py
# Cruza: FinAI (investments current_amount) + Life OS (financial_accounts current_balance)
# Salva em net_worth_snapshots com breakdown JSONB
# Output JSON: {date, total_assets, total_liabilities, net_worth, breakdown}
```

### query_net_worth.py — Historico de Patrimonio
```bash
python3 scripts/query_net_worth.py [--months N]
# Default: 12 meses
# Output JSON: {snapshots: [{date, assets, liabilities, net_worth, breakdown}]}
```

## Tabelas

### financial_goals
- title, target_amount, current_amount, target_date, priority (1-5), status, strategy

### net_worth_snapshots
- total_assets, total_liabilities, net_worth, breakdown (JSONB), snapshot_date
- Constraint: unique(user_id, snapshot_date) — 1 snapshot/dia

### financial_accounts
- name, account_type (checking/savings/investment/credit_card/crypto/other), institution, current_balance
