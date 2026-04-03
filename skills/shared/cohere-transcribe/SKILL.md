---
name: cohere-transcribe
description: 'Transcrever áudio via Cohere Transcribe API (modelo open-source 2B, 14 idiomas incluindo PT-BR). Use quando: (1) usuário enviar áudio/voz no Telegram/WhatsApp, (2) pedir transcrição de arquivos de áudio, (3) precisar de alternativa ao Whisper. API gratuita com rate limits. Suporta FLAC, MP3, MPEG, MPGA, OGG, WAV até 25MB.'
metadata:
  {
    "openclaw": { "emoji": "🎙️", "requires": { "env": ["COHERE_API_KEY"] } },
  }
---

# Cohere Transcribe Skill

Transcreva áudio usando a API do Cohere Transcribe — modelo open-source de 2B parâmetros com SOTA em 14 idiomas.

## 📋 Model Details

- **Modelo**: `cohere-transcribe-03-2026`
- **Licença**: Apache 2.0
- **Idiomas**: EN, DE, FR, IT, ES, **PT**, GR, NL, PL, VN, ZH, AR, JA, KO
- **Max arquivo**: 25MB
- **Formatos**: FLAC, MP3, MPEG, MPGA, OGG, WAV
- **API**: Gratuita com rate limits (trial)

## 🔑 Pré-requisitos

### 1. Obter API Key

```bash
# Acesse https://dashboard.cohere.com/api-keys
# Crie uma trial key
```

### 2. Configurar variável de ambiente

Adicione ao `~/.zshrc`:

```bash
export COHERE_API_KEY="sua-key-aqui"
```

Recarregue:

```bash
source ~/.zshrc
```

## 🚀 Uso Básico

### Via curl

```bash
curl -X POST "https://api.cohere.com/v2/audio/transcriptions" \
  -H "Authorization: Bearer $COHERE_API_KEY" \
  -F "model=cohere-transcribe-03-2026" \
  -F "language=pt" \
  -F "file=@/caminho/do/audio.wav"
```

### Via Python

```python
import cohere

co = cohere.Client(api_key=COHERE_API_KEY)
response = co.audio.transcriptions.create(
    model="cohere-transcribe-03-2026",
    file=open("audio.wav", "rb"),
    language="pt"
)
print(response.text)
```

## 📦 Script de Transcrição

Crie `transcribe.sh` no diretório do skill:

```bash
#!/bin/bash
# cohere-transcribe/transcribe.sh

set -e

if [ -z "$COHERE_API_KEY" ]; then
    echo "❌ Erro: COHERE_API_KEY não definida"
    echo "Adicione ao ~/.zshrc: export COHERE_API_KEY='sua-key'"
    exit 1
fi

if [ -z "$1" ]; then
    echo "Uso: $0 <arquivo_de_audio>"
    echo "Formatos: FLAC, MP3, MPEG, MPGA, OGG, WAV (max 25MB)"
    exit 1
fi

AUDIO_FILE="$1"
LANGUAGE="${2:-pt}"  # Default: português

if [ ! -f "$AUDIO_FILE" ]; then
    echo "❌ Arquivo não encontrado: $AUDIO_FILE"
    exit 1
fi

# Verificar tamanho do arquivo
FILE_SIZE=$(stat -f%z "$AUDIO_FILE" 2>/dev/null || stat -c%s "$AUDIO_FILE" 2>/dev/null)
MAX_SIZE=$((25 * 1024 * 1024))  # 25MB

if [ "$FILE_SIZE" -gt "$MAX_SIZE" ]; then
    echo "❌ Arquivo muito grande: $(echo "scale=2; $FILE_SIZE/1024/1024" | bc)MB (max 25MB)"
    exit 1
fi

echo "🎙️ Transcrevendo: $AUDIO_FILE"
echo "🌐 Idioma: $LANGUAGE"

RESPONSE=$(curl -s -X POST "https://api.cohere.com/v2/audio/transcriptions" \
  -H "Authorization: Bearer $COHERE_API_KEY" \
  -F "model=cohere-transcribe-03-2026" \
  -F "language=$LANGUAGE" \
  -F "file=@$AUDIO_FILE")

# Extrair texto do JSON
TRANSCRIPTION=$(echo "$RESPONSE" | jq -r '.text // empty')

if [ -z "$TRANSCRIPTION" ]; then
    echo "❌ Erro na transcrição:"
    echo "$RESPONSE" | jq .
    exit 1
fi

echo ""
echo "✅ Transcrição concluída:"
echo "─────────────────────────"
echo "$TRANSCRIPTION"
echo "─────────────────────────"
```

Torne executável:

```bash
chmod +x transcribe.sh
```

## 🔗 Integração com OpenClaw

### Skill de transcrição automática

Quando usuário enviar áudio no Telegram:

```bash
# 1. Salvar áudio em /tmp
# 2. Rodar o script de transcrição
# 3. Enviar transcrição de volta
```

### Exemplo de fluxo

```bash
# Salvar áudio do Telegram
MEDIA_PATH="/tmp/audio_$(date +%s).wav"

# Transcrever
./transcribe.sh "$MEDIA_PATH" pt

# Enviar resposta via message tool
```

## 📊 Comparação: Cohere vs Whisper

| Feature | Cohere Transcribe | OpenAI Whisper |
|---------|-------------------|----------------|
| Modelo | 2B params | 1.5B (base) - 1.5B (large) |
| Licenciamento | Apache 2.0 | MIT |
| API Gratuita | ✅ Sim (trial) | ❌ Paga por uso |
| Idiomas | 14 | 99+ |
| Max arquivo | 25MB | 25MB |
| Latência | ~3x mais rápido | Padrão |
| Local | ✅ Hugging Face | ✅ Open-source |

## ⚠️ Limitações

- **Sem detecção automática de idioma** — precisa especificar
- **Sem timestamps** — apenas texto transcrito
- **Sem diarização de speakers** — não identifica quem fala
- **Single language** — performa melhor com áudio em um único idioma

## 🛠️ Troubleshooting

### Erro 401 Unauthorized

```bash
# Verificar se API key está definida
echo $COHERE_API_KEY

# Se vazia, adicionar ao ~/.zshrc e recarregar
```

### Erro 413 Payload Too Large

```bash
# Arquivo > 25MB. Reduzir com ffmpeg:
ffmpeg -i input.wav -ar 16000 -ac 1 output.wav
```

### Erro 429 Rate Limit

```bash
# Trial keys têm rate limits. Aguardar ou upgrade para production.
```

## 📚 Referências

- [Docs Oficiais](https://docs.cohere.com/docs/transcribe)
- [Hugging Face](https://huggingface.co/CohereLabs/cohere-transcribe-03-2026)
- [API Reference](https://docs.cohere.com/reference/create-audio-transcription)
- [Blog Post](https://cohere.com/blog/transcribe)
