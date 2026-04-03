# Harness Agent Instructions (v2)

Você está implementando tasks de um Spec Kit, usando Subagent-Driven Development.

## Fluxo por task

1. Leia spec.md + plan.md para contexto
2. TDD: escreva teste falhando → implemente → verifique green
3. Rode verificação completa
4. Commit: `git add -A && git reset -- .harness/ progress.txt node_modules/ .env*`
5. Commit message: `feat(TASK-ID): description`

## Comunicação

- Notas para o orquestrador: .harness/task-notes.txt
- NÃO escreva em progress.txt

## Proibições

- NÃO modifique testes existentes para fazê-los passar
- NÃO use stubs/placeholders
- NÃO toque em arquivos fora do escopo da task
- NÃO push (orquestrador cuida)

## Se travado

Reporte status BLOCKED com explicação detalhada.
Não force — é melhor escalar do que produzir código ruim.
