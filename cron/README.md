# Cron Jobs

Jobs agendados via OpenClaw cron. O arquivo `jobs.json` contem a definicao completa de todos os 12 jobs.

## Jobs ativos

| Job                        | Schedule      | Agente        | Descricao                           |
| -------------------------- | ------------- | ------------- | ----------------------------------- |
| Relatorio Matinal          | 7:30 diario   | main          | Status do servidor via Telegram     |
| AI Daily Digest            | 8h, 12h, 18h  | main          | Curadoria de noticias AI (Miniflux) |
| Daily Review               | 20:30 diario  | health-coach  | Review de saude/nutricao            |
| English Wake-up            | 6:30 seg-sex  | english-tutor | Ping matinal de ingles              |
| English Micro-dose Lunch   | 12:30 seg-sex | english-tutor | Exercicio rapido                    |
| English Micro-dose Evening | 18h seg-sex   | english-tutor | Pergunta casual                     |
| English Daily Vocab        | 21h diario    | english-tutor | 3 palavras novas                    |
| English Weekend Casual     | 10h sabado    | english-tutor | Conversa descontraida               |
| API Spending Semanal       | 20h domingo   | main          | Custos semanais de APIs             |

## Jobs desabilitados

| Job                 | Motivo                   |
| ------------------- | ------------------------ |
| API Spending Diario | Substituido pelo semanal |

## Variaveis

Os jobs usam `${TELEGRAM_CHAT_ID}` como placeholder. Preencha com seu chat ID.

## Como adaptar

Para usar fora do OpenClaw, converta para `crontab`:

```bash
# Exemplo: Daily Digest as 8h
0 8 * * * cd ~/.openclaw/skills/ai-daily-digest && python3 scripts/fetch_miniflux.py
```
