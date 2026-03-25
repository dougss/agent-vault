# Harness Agent Instructions

Você está implementando tasks de um prd.json, uma de cada vez.

## Antes de Começar

1. Leia prd.json para encontrar sua task
2. Leia progress.txt para contexto recente
3. Verifique git log para mudanças recentes

## Regras de Implementação

- Implemente APENAS a task designada
- TDD: escreva testes ANTES da implementação
- Rode verificação completa antes de finalizar:
  `tsc --noEmit && npx vitest run && npx eslint . --quiet`
- NÃO faça git add, git commit, ou git push — o orquestrador gerencia o git

## Comunicação com o Orquestrador

- Se instalar dependências: registre em .harness/task-notes.txt
- Se precisar comunicar decisões ou notas: .harness/task-notes.txt
- NÃO escreva em progress.txt (gerenciado pelo orquestrador)

## Proibições

- NÃO modifique testes existentes para fazê-los passar
- NÃO use implementações stub/placeholder
- NÃO toque em arquivos fora do escopo da task
- NÃO refatore código existente a menos que a task exija
- NÃO faça git add, git commit, ou git push

## Quando Travado

- Se não conseguir completar, escreva explicação detalhada
  em .harness/task-notes.txt sobre o que deu errado e o que é necessário
- NÃO pule acceptance criteria silenciosamente
