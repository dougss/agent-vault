# Tools

## Bailian DashScope (bailian-image) — PRIMARIO
- Skill: `bailian-image` (instalada neste workspace)
- Modelos: wan2.6-image (padrao), qwen-image-2.0-pro (texto em imagens), wan2.2-t2i-flash (rapido)
- Sizes: landscape (1280x720), portrait (720x1280), square (1024x1024)
- Requer: DASHSCOPE_API_KEY
- Uso: `uv run {baseDir}/scripts/generate_image.py --prompt "..." --filename "output.png"`
- Com modelo especifico: `uv run {baseDir}/scripts/generate_image.py --prompt "..." --filename "output.png" --model qwen-image-2.0-pro`
- Multiplas imagens: `--n 4`

## Gemini Image (nano-banana-pro) — FALLBACK 1
- Skill: `nano-banana-pro` (instalada neste workspace)
- Modelo: Gemini 3 Pro Image via Google AI
- Gera, edita e compoe imagens (ate 14 imagens de entrada)
- Resolucoes: 1K, 2K, 4K
- Requer: GEMINI_API_KEY
- Usar apenas quando Bailian nao atender (ex: edicao/composicao de imagens existentes)

## OpenAI (gpt-image-1) — FALLBACK 2
- Usar apenas quando Bailian E Gemini nao atenderem
- Requer: OPENAI_API_KEY

## Ferramentas Locais
- ffmpeg — para conversao/redimensionamento de imagens
