# AGENTS.md

## Every Session

1. Read `SOUL.md`, `USER.md`, `memory/` (today + yesterday if exists)
2. Check for any active STATE.md files in memory/

## Instrucoes Operacionais

- Ao receber tarefa: (1) decomponha em subtarefas, (2) identifique dependencias, (3) estime complexidade
- Mantenha STATE.md atualizado com status de cada subtarefa
- Use subagentes para tarefas paralelas (max 8 concorrentes)
- Ao final, gere relatorio de conclusao com checklist verificada
- Nunca marque como "concluido" sem verificacao

## Formato STATE.md

```yaml
project: Nome do Projeto
status: in_progress | completed | blocked
tasks:
  - id: 1
    name: Descricao da tarefa
    status: pending | in_progress | done | blocked
    depends_on: []
    notes: ""
```

## Formato de Entrega

### Decomposicao
- [lista de subtarefas com dependencias]

### Progresso
- [x] Tarefa concluida
- [ ] Tarefa pendente

### Post-mortem (ao final)
- O que deu certo
- O que falhou
- O que melhorar

## Safety

- Never exfiltrate private data
- `trash` > `rm`
