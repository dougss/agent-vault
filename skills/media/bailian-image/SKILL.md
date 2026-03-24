---
name: bailian-image
description: Generate images via Alibaba Cloud Bailian DashScope (wan2.6-image, qwen-image-2.0-pro, wan2.2-t2i-flash).
homepage: https://www.alibabacloud.com/en/product/model-studio
metadata:
  {
    "openclaw":
      {
        "emoji": "🎨",
        "requires": { "bins": ["uv"], "env": ["DASHSCOPE_API_KEY"] },
        "primaryEnv": "DASHSCOPE_API_KEY",
        "install":
          [
            {
              "id": "uv-brew",
              "kind": "brew",
              "formula": "uv",
              "bins": ["uv"],
              "label": "Install uv (brew)",
            },
          ],
      },
  }
---

# Bailian Image (DashScope)

Use the bundled script to generate images via Alibaba Cloud DashScope API.

## Generate (default: wan2.6-image)

```bash
uv run {baseDir}/scripts/generate_image.py --prompt "your image description" --filename "output.png"
```

## With specific model

```bash
uv run {baseDir}/scripts/generate_image.py --prompt "text with rendered words" --filename "output.png" --model qwen-image-2.0-pro
```

## Fast iteration

```bash
uv run {baseDir}/scripts/generate_image.py --prompt "quick draft" --filename "output.png" --model wan2.2-t2i-flash
```

## Sizes

Use `--size` with: `landscape` (1280x720), `portrait` (720x1280), `square` (1024x1024), or explicit `WxH`.

```bash
uv run {baseDir}/scripts/generate_image.py --prompt "portrait photo" --filename "output.png" --size portrait
```

## Multiple images

```bash
uv run {baseDir}/scripts/generate_image.py --prompt "variations" --filename "output.png" --n 4
```

## API key

- `DASHSCOPE_API_KEY` or `BAILIAN_API_KEY` env var
- Or pass `--api-key`

## Models

| Model | Use case |
|-------|----------|
| wan2.6-image | Default. Best quality, streaming API. Supports editing with `-i` |
| qwen-image-2.0-pro | Images with rendered text (async API) |
| wan2.2-t2i-flash | Fast iteration, lower quality (async API) |

## Image editing (wan2.6-image only)

```bash
uv run {baseDir}/scripts/generate_image.py --prompt "make it sunset" --filename "output.png" -i input.png
```

## Notes

- wan2.6-image uses streaming API; other models use async task + polling.
- Use timestamps in filenames: `yyyy-mm-dd-hh-mm-ss-name.png`.
- The script prints `MEDIA:` lines for OpenClaw auto-attach.
- Do not read the image back; report the saved path only.
