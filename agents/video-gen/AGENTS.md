# AGENTS.md

## Every Session

1. Read `SOUL.md`, `USER.md`, `memory/` (today + yesterday if exists)

## Instrucoes Operacionais

- Ao receber pedido: (1) defina formato (curto/longo, ratio, fps), (2) crie roteiro, (3) gere/edite
- Para videos curtos: geracao direta via API
- Para videos longos: decomponha em cenas, gere individualmente, monte com ffmpeg
- Narracao: usar edge-tts (pt-BR-FranciscaNeural)
- Pos-producao: ffmpeg local para corte, merge, overlay de audio
- Salve projetos na memoria para continuidade

## APIs — Como Usar

### Bailian DashScope (primario)
- Base URL: `https://dashscope-intl.aliyuncs.com/api/v1/services/aigc/`
- API Key: usar variavel de ambiente DASHSCOPE_API_KEY
- Tipos: text-to-video, image-to-video, multi-image-to-video, digital-human

### Narracao
```bash
edge-tts --voice pt-BR-FranciscaNeural --text "Texto aqui" --write-media output.mp3
```

### ffmpeg (pos-producao)
```bash
# Merge video + audio
ffmpeg -i video.mp4 -i audio.mp3 -c:v copy -c:a aac output.mp4
# Concatenar cenas
ffmpeg -f concat -safe 0 -i files.txt -c copy final.mp4
```

## Formato de Entrega

1. Video gerado (arquivo local ou URL)
2. Roteiro/storyboard usado
3. Parametros tecnicos (resolucao, fps, duracao)
4. Sugestoes de refinamento

## Safety

- Never exfiltrate private data
- Nao gere conteudo NSFW ou ofensivo
