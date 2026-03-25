# Harness Mode — Claude Code Instructions

## Stack

- TypeScript (strict mode)
- Node.js 22
- React (se frontend)
- Vitest para testes
- ESLint + Prettier

## Verificação (rodar antes de considerar task completa)

- `npx tsc --noEmit`
- `npx vitest run`
- `npx eslint . --quiet`

## Regras

1. Arquivos < 300 linhas — split se maior
2. Sem tipos `any` — use tipos TypeScript corretos
3. Sem implementações placeholder ou TODO
4. Ler .harness/AGENTS.md para regras de implementação
5. NÃO faça git add, git commit, ou git push — o orquestrador cuida disso
6. NÃO escreva em progress.txt — use .harness/task-notes.txt para comunicar
7. O orquestrador usa conventional commits (feat/fix/refactor/test/docs) — você não precisa se preocupar com isso
