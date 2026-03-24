#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "requests>=2.31.0",
#     "pillow>=10.0.0",
# ]
# ///
"""
Generate or edit images using Alibaba Cloud Bailian DashScope API.

Models:
  - wan2.6-image       (default) — high quality, text-to-image & editing
  - qwen-image-2.0-pro           — text rendering in images (async API)
  - wan2.2-t2i-flash              — fast iteration (async API)

Usage:
    uv run generate_image.py --prompt "description" --filename "output.png"
    uv run generate_image.py --prompt "description" --filename "output.png" --model qwen-image-2.0-pro
    uv run generate_image.py --prompt "edit this" --filename "output.png" -i input.png
"""

import argparse
import base64
import json
import os
import sys
import time
import requests
from io import BytesIO
from pathlib import Path

DASHSCOPE_BASE = "https://dashscope-intl.aliyuncs.com/api/v1"

# wan2.6-image uses the multimodal-generation streaming API
# Other models use the legacy text2image async API
MULTIMODAL_MODELS = {"wan2.6-image"}

MODELS = {
    "wan2.6-image": {
        "sizes": ["768*768", "1024*1024", "1280*720", "720*1280", "1280*1280"],
        "default_size": "1280*720",
    },
    "qwen-image-2.0-pro": {
        "sizes": ["1024*1024", "768*1024", "1024*768", "720*1280", "1280*720"],
        "default_size": "1024*1024",
    },
    "wan2.2-t2i-flash": {
        "sizes": ["1024*1024", "768*1024", "1024*768", "720*1280", "1280*720"],
        "default_size": "1024*1024",
    },
}

SIZE_ALIASES = {
    "landscape": "1280*720",
    "portrait": "720*1280",
    "square": "1024*1024",
    "hd": "1280*1280",
}


def get_api_key(provided_key: str | None) -> str | None:
    if provided_key:
        return provided_key
    return os.environ.get("DASHSCOPE_API_KEY") or os.environ.get("BAILIAN_API_KEY")


def normalize_size(size_str: str) -> str:
    lower = size_str.lower()
    if lower in SIZE_ALIASES:
        return SIZE_ALIASES[lower]
    return size_str.replace("x", "*")


# ---------------------------------------------------------------------------
# wan2.6-image — streaming multimodal-generation API
# ---------------------------------------------------------------------------

def generate_wan26(api_key: str, prompt: str, size: str, input_images: list[str] | None) -> tuple[list[bytes], str]:
    """Generate images via wan2.6-image streaming API. Returns (image_bytes_list, model_text)."""
    url = f"{DASHSCOPE_BASE}/services/aigc/multimodal-generation/generation"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "X-DashScope-SSE": "enable",
    }

    content = [{"text": prompt}]
    enable_interleave = True

    if input_images:
        # Editing mode: include images, disable interleave
        for img_path in input_images:
            img_data = Path(img_path).read_bytes()
            b64 = base64.b64encode(img_data).decode()
            mime = "image/png" if img_path.lower().endswith(".png") else "image/jpeg"
            content.insert(0, {"image": f"data:{mime};base64,{b64}"})
        enable_interleave = False

    payload = {
        "model": "wan2.6-image",
        "input": {
            "messages": [{"role": "user", "content": content}]
        },
        "parameters": {
            "enable_interleave": enable_interleave,
            "stream": True,
            "size": size,
            "prompt_extend": True,
            "watermark": False,
        },
    }

    if enable_interleave:
        payload["parameters"]["max_images"] = 1

    if not enable_interleave:
        payload["parameters"]["n"] = 1

    resp = requests.post(url, json=payload, headers=headers, stream=True, timeout=300)
    if resp.status_code != 200:
        print(f"Error: HTTP {resp.status_code}", file=sys.stderr)
        print(resp.text, file=sys.stderr)
        sys.exit(1)

    images: list[bytes] = []
    text_parts: list[str] = []

    for line in resp.iter_lines(decode_unicode=True):
        if not line or not line.startswith("data:"):
            continue

        data_str = line[len("data:"):]
        try:
            data = json.loads(data_str)
        except json.JSONDecodeError:
            continue

        choices = data.get("output", {}).get("choices", [])
        if not choices:
            continue

        msg_content = choices[0].get("message", {}).get("content", [])
        for part in msg_content:
            if isinstance(part, dict):
                if "text" in part and part["text"]:
                    text_parts.append(part["text"])
                elif "image" in part and part["image"]:
                    img_str = part["image"]
                    # Could be base64 data URI or URL
                    if img_str.startswith("data:"):
                        # data:image/png;base64,xxxxx
                        b64_data = img_str.split(",", 1)[1]
                        images.append(base64.b64decode(b64_data))
                    elif img_str.startswith("http"):
                        img_resp = requests.get(img_str, timeout=60)
                        if img_resp.status_code == 200:
                            images.append(img_resp.content)

        finish = choices[0].get("finish_reason")
        if finish and finish != "null":
            break

    model_text = "".join(text_parts).strip()
    return images, model_text


# ---------------------------------------------------------------------------
# Legacy async text2image API (qwen-image, wan2.2-t2i-flash, etc.)
# ---------------------------------------------------------------------------

def generate_legacy(api_key: str, model: str, prompt: str, size: str, n: int) -> list[str]:
    """Generate images via async text2image API. Returns list of image URLs."""
    url = f"{DASHSCOPE_BASE}/services/aigc/text2image/image-synthesis"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "X-DashScope-Async": "enable",
    }
    payload = {
        "model": model,
        "input": {"prompt": prompt},
        "parameters": {"size": size, "n": n},
    }

    resp = requests.post(url, json=payload, headers=headers, timeout=30)
    if resp.status_code != 200:
        print(f"Error submitting task: {resp.status_code}", file=sys.stderr)
        print(resp.text, file=sys.stderr)
        sys.exit(1)

    data = resp.json()
    task_id = data.get("output", {}).get("task_id")
    if not task_id:
        print(f"Error: no task_id: {data}", file=sys.stderr)
        sys.exit(1)

    print(f"Task submitted: {task_id}")

    # Poll for completion
    poll_url = f"{DASHSCOPE_BASE}/tasks/{task_id}"
    poll_headers = {"Authorization": f"Bearer {api_key}"}
    elapsed = 0

    while elapsed < 300:
        time.sleep(3)
        elapsed += 3
        r = requests.get(poll_url, headers=poll_headers, timeout=30)
        if r.status_code != 200:
            print(f"Error polling: {r.status_code}", file=sys.stderr)
            sys.exit(1)
        out = r.json().get("output", {})
        status = out.get("task_status")
        if status == "SUCCEEDED":
            return [res["url"] for res in out.get("results", []) if res.get("url")]
        elif status == "FAILED":
            print(f"Error: task failed — {out.get('message', 'unknown')}", file=sys.stderr)
            sys.exit(1)

    print("Error: task timed out", file=sys.stderr)
    sys.exit(1)


def save_image(data: bytes, output_path: Path) -> None:
    from PIL import Image as PILImage
    output_path.parent.mkdir(parents=True, exist_ok=True)
    img = PILImage.open(BytesIO(data))
    if img.mode == "RGBA":
        rgb = PILImage.new("RGB", img.size, (255, 255, 255))
        rgb.paste(img, mask=img.split()[3])
        rgb.save(str(output_path), "PNG")
    else:
        img.convert("RGB").save(str(output_path), "PNG")


def main():
    parser = argparse.ArgumentParser(
        description="Generate images using Bailian DashScope API"
    )
    parser.add_argument("--prompt", "-p", required=True, help="Image description")
    parser.add_argument("--filename", "-f", required=True, help="Output filename")
    parser.add_argument(
        "--model", "-m",
        choices=list(MODELS.keys()),
        default="wan2.6-image",
        help="Model (default: wan2.6-image)",
    )
    parser.add_argument(
        "--size", "-s", default=None,
        help="Size: landscape, portrait, square, hd, or W*H",
    )
    parser.add_argument(
        "--input-image", "-i", action="append", dest="input_images", metavar="IMAGE",
        help="Input image(s) for editing (wan2.6-image only)",
    )
    parser.add_argument(
        "--n", type=int, default=1, choices=[1, 2, 3, 4],
        help="Number of images (legacy models only, default: 1)",
    )
    parser.add_argument("--api-key", "-k", help="DashScope API key")

    args = parser.parse_args()

    api_key = get_api_key(args.api_key)
    if not api_key:
        print("Error: No API key. Set DASHSCOPE_API_KEY env var or pass --api-key", file=sys.stderr)
        sys.exit(1)

    model_info = MODELS[args.model]
    size = normalize_size(args.size) if args.size else model_info["default_size"]
    output_path = Path(args.filename)

    print(f"Generating with {args.model} at {size}...")

    if args.model in MULTIMODAL_MODELS:
        # wan2.6-image — streaming API
        images_data, model_text = generate_wan26(api_key, args.prompt, size, args.input_images)

        if model_text:
            print(f"Model response: {model_text}")

        if not images_data:
            print("Error: no images generated", file=sys.stderr)
            sys.exit(1)

        for i, img_bytes in enumerate(images_data):
            if len(images_data) > 1:
                path = output_path.parent / f"{output_path.stem}-{i+1:02d}{output_path.suffix or '.png'}"
            else:
                path = output_path
            save_image(img_bytes, path)
            full = path.resolve()
            print(f"\nImage saved: {full}")
            print(f"MEDIA:{full}")
    else:
        # Legacy async API
        urls = generate_legacy(api_key, args.model, args.prompt, size, args.n)

        if not urls:
            print("Error: no images in response", file=sys.stderr)
            sys.exit(1)

        for i, url in enumerate(urls):
            if len(urls) > 1:
                path = output_path.parent / f"{output_path.stem}-{i+1:02d}{output_path.suffix or '.png'}"
            else:
                path = output_path
            resp = requests.get(url, timeout=60)
            if resp.status_code != 200:
                print(f"Error downloading image {i}: {resp.status_code}", file=sys.stderr)
                continue
            save_image(resp.content, path)
            full = path.resolve()
            print(f"\nImage saved: {full}")
            print(f"MEDIA:{full}")

    print("Done.")


if __name__ == "__main__":
    main()
