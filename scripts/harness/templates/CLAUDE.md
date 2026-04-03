# Harness Mode — Claude Code Instructions (v2)

## Stack

- TypeScript (strict mode), Node.js 22
- React (se frontend), Vitest, ESLint + Prettier

## Specs

Este projeto usa Spec Kit. Leia os specs em `specs/<feature>/`:

- spec.md — O QUE e POR QUÊ
- plan.md — COMO (arquitetura, data model)
- tasks.md — breakdown de tasks

## Verificação

Rodar ANTES de considerar qualquer task completa:

```
npx tsc --noEmit && npx vitest run && npx eslint . --quiet
```

## Skills

- Use `superpowers:test-driven-development` — TDD obrigatório
- Use `superpowers:verification-before-completion` — verificar antes de reportar

## Regras

1. Arquivos < 300 linhas
2. Sem `any` — tipos TypeScript corretos
3. Sem placeholders ou TODO
4. Um commit por task: `feat(T001): description`
5. NÃO commitar: .harness/, progress.txt, node_modules/, .env\*
6. NÃO push (orquestrador cuida)
