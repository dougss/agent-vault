# Skill: Registrar na Knowledge Base

## Procedimento

### 1. Capturar Contexto

- Salve o diretorio atual: ORIGIN_DIR=$(pwd)
- Se existir CLAUDE.md no diretorio atual, leia para identificar o projeto
- Se nao existir, use o nome da pasta como contexto

### 2. Navegar ao Vault

cd ~/Obsidian-Mind

### 3. Orientacao

- Leia _System/VAULT-INDEX.md (visao geral das pastas)
- Leia _System/Conventions.md (front matter, tags, regras)

### 4. Determinar Destino

Com base no conteudo a registrar, determine:

- domain: dev | finance | health | psychology | english | productivity | self-hosted
- Subpasta especifica dentro de 03-Resources/{domain}/
- Se for sobre um projeto ativo: pode ir para 02-Projects/{projeto}/ ao inves

### 5. Verificar Duplicatas

grep -r "termo-chave" --include="*.md" 03-Resources/{domain}/

- Se encontrar nota similar: ATUALIZAR (adicionar secao, nao reescrever)
- Se nao encontrar: CRIAR nova nota

### 6. Criar/Atualizar Nota

Front matter obrigatorio:

```yaml
---
title: "Titulo descritivo"
created: YYYY-MM-DD
updated: YYYY-MM-DD
type: reference
domain: {domain}
tags: [tag1, tag2]
status: seed
source: "{nome-do-projeto} — {diretorio}"
related: ["[[notas relacionadas]]"]
---
```

Conteudo:

- Resumo claro do que foi descoberto/aprendido
- Contexto de onde veio (projeto, situacao)
- Detalhes tecnicos se aplicavel
- Links para documentacao se aplicavel

### 7. Atualizar Index

- Leia 03-Resources/{domain}/index.md
- Adicione a nova nota na lista
- Salve

### 8. Referencia Cruzada

- Se existir daily note de hoje (01-Daily/), adicione mencao
- Crie [[wikilinks]] para notas relacionadas que encontrou

### 9. Retornar

cd $ORIGIN_DIR

### 10. Confirmar

Informe: "Registrado em [path relativo] — domain: {domain}, tags: [tags]"
