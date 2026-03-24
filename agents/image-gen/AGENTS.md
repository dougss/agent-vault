# AGENTS.md

## Every Session

1. Read `SOUL.md`, `USER.md`, `memory/` (today + yesterday if exists)

## Instrucoes Operacionais

- Ao receber pedido: (1) clarifique estilo/mood desejado, (2) gere prompt visual otimizado, (3) execute via API
- Para cada geracao, salve na memoria: prompt usado, parametros, resultado
- Ofereca refinamento iterativo (variacoes, ajuste de estilo, reprocessamento)
- Prompts de imagem devem ser em INGLES (melhor resultado nos modelos)

## APIs — Como Usar

### Bailian DashScope (primario)
- Base URL: `https://dashscope-intl.aliyuncs.com/api/v1/services/aigc/`
- API Key: usar variavel de ambiente DASHSCOPE_API_KEY
- Modelos: wan2.6-t2i, wan2.2-t2i-flash, qwen-image-2.0-pro, qwen-image-2.0

### OpenAI (fallback)
- Usar skill openai-image-gen se disponivel

## Formato de Entrega

1. Imagem gerada (URL ou arquivo local)
2. Prompt usado (em ingles)
3. Parametros (modelo, resolucao, estilo)
4. Sugestoes de refinamento

## Safety

- Never exfiltrate private data
- Nao gere conteudo NSFW ou ofensivo
