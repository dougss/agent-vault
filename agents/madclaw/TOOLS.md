# Tools — Notas locais

## Obsidian Vault (Obsidian-Mind)

Localização: ~/Obsidian-Mind/
Sync: Obsidian Sync (sempre ativo, app rodando em background)

### Estrutura
- 00-Inbox/       → Notas rápidas, triagem
- 01-Daily/       → Daily notes
- 02-Projects/    → Projetos ativos
- 03-Resources/   → Referências, knowledge base
- 04-Archive/     → Projetos encerrados
- 05-Work/        → Trabalho (tech lead)
- Attachments/    → Imagens e anexos
- Excalidraw/     → Diagramas
- Feeds/          → Conteúdo de feeds/leitura
- Treinos/        → Treinos físicos
- _System/        → Templates e configs do Obsidian
- _private/       → ⛔ NUNCA ACESSAR (dados sensíveis pessoais)

### Regras
- NUNCA ler, listar, buscar ou mencionar arquivos em _private/
- Ao criar notas, usar formato Obsidian: YAML frontmatter + markdown
- Links internos: [[Nome da Nota]]
- Tags: #tag
- Novas notas rápidas vão em 00-Inbox/
- Daily notes em 01-Daily/ com formato YYYY-MM-DD.md
- Após criar/editar arquivo, o Obsidian Sync propaga automaticamente

### Exemplo de nota nova
```markdown
---
created: 2026-02-25
tags: [inbox, idea]
---

# Título da Nota

Conteúdo aqui. Link para [[Outra Nota]].
```

### Comandos úteis
```bash
# Buscar nota por nome
find ~/Obsidian-Mind/ -name "*.md" -not -path "*/_private/*" | grep -i "termo"

# Buscar conteúdo em notas (excluindo _private)
grep -ri "termo" ~/Obsidian-Mind/ --include="*.md" --exclude-dir="_private"

# Criar nota rápida no Inbox
echo '---\ncreated: '$(date +%Y-%m-%d)'\ntags: [inbox]\n---\n\n# Título\n\nConteúdo' > ~/Obsidian-Mind/00-Inbox/titulo.md
```
