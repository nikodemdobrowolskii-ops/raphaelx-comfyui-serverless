#!/bin/bash
# RunPod Serverless Startup Script — MrSmith v6 Ultimate
# 1. Downloads missing models to network volume
# 2. Creates symlinks from volume to ComfyUI
# 3. Starts the handler

set -e

COMFYUI_DIR="${COMFYUI_DIR:-/comfyui}"
VOLUME_DIR="/runpod-volume"
MODELS_DIR="${VOLUME_DIR}/models"

echo "=== RunPod Serverless Startup (MrSmith v6) ==="
echo "ComfyUI dir: ${COMFYUI_DIR}"
echo "Volume dir: ${VOLUME_DIR}"

# ============================================================
# Create all model directories on volume (if not exist)
# ============================================================
mkdir -p "${MODELS_DIR}/checkpoints"
mkdir -p "${MODELS_DIR}/vae"
mkdir -p "${MODELS_DIR}/loras"
mkdir -p "${MODELS_DIR}/loras/Z-Image"
mkdir -p "${MODELS_DIR}/loras/Characters"
mkdir -p "${MODELS_DIR}/loras/SDXL"
mkdir -p "${MODELS_DIR}/unet"
mkdir -p "${MODELS_DIR}/clip"
mkdir -p "${MODELS_DIR}/upscale_models"
mkdir -p "${MODELS_DIR}/ultralytics/bbox"
mkdir -p "${MODELS_DIR}/sams"
mkdir -p "${MODELS_DIR}/diffusion_models"
mkdir -p "${MODELS_DIR}/text_encoders"
mkdir -p "${MODELS_DIR}/SEEDVR2"
mkdir -p "${MODELS_DIR}/controlnet"
mkdir -p "${MODELS_DIR}/embeddings"

# ============================================================
# Download missing models (only if not already on volume)
# ============================================================
download_model() {
    local url="$1"
    local dest="$2"
    local name=$(basename "$dest")

    if [ -f "$dest" ]; then
        local size=$(stat -c%s "$dest" 2>/dev/null || stat -f%z "$dest" 2>/dev/null)
        if [ "$size" -gt 1000000 ]; then
            echo "  Already exists: $name ($(numfmt --to=iec $size 2>/dev/null || echo ${size} bytes))"
            return 0
        fi
        echo "  File too small, re-downloading: $name"
        rm -f "$dest"
    fi

    echo "  Downloading: $name ..."
    wget -q --show-progress -c "$url" -O "$dest" || {
        echo "  FAILED to download: $name"
        rm -f "$dest"
        return 1
    }
    echo "  Done: $name"
}

echo ""
echo "=== Checking/downloading models ==="

# Z-Image Turbo BF16 (~11GB) — main generation model
download_model \
    "https://huggingface.co/aoxo/z-image/resolve/main/z_image_turbo_bf16.safetensors" \
    "${MODELS_DIR}/diffusion_models/z_image_turbo_bf16.safetensors"

# Qwen 3 4B Text Encoder (~7.5GB)
download_model \
    "https://huggingface.co/Comfy-Org/Qwen2.5_VL_3B_Instruct_repackaged/resolve/main/qwen_3_4b.safetensors" \
    "${MODELS_DIR}/text_encoders/qwen_3_4b.safetensors"

# VAE ae.safetensors (~320MB)
download_model \
    "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors" \
    "${MODELS_DIR}/vae/ae.safetensors"

# SAM Model (~375MB)
download_model \
    "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth" \
    "${MODELS_DIR}/sams/sam_vit_b_01ec64.pth"

# SeedVR2 Q4 GGUF (~4.4GB) — upscaler
download_model \
    "https://huggingface.co/cmeka/SeedVR2-GGUF/resolve/main/seedvr2_ema_7b-Q4_K_M.gguf" \
    "${MODELS_DIR}/SEEDVR2/seedvr2_ema_7b-Q4_K_M.gguf"

# SeedVR2 VAE (~478MB)
download_model \
    "https://huggingface.co/numz/SeedVR2_comfyUI/resolve/main/ema_vae_fp16.safetensors" \
    "${MODELS_DIR}/SEEDVR2/ema_vae_fp16.safetensors"

# epiCRealism XL v17 Crystal Clear (~6.5GB) — SDXL Pre-Definer checkpoint for MrSmith v6
# CivitAI model 277058 v847189. Token required via env CIVITAI_TOKEN.
SDXL_CKPT="${MODELS_DIR}/checkpoints/(SDXL)_epiCRealismXL_VXVII_CrystalClear.safetensors"
if [ ! -f "$SDXL_CKPT" ] || [ "$(stat -c%s "$SDXL_CKPT" 2>/dev/null || stat -f%z "$SDXL_CKPT" 2>/dev/null || echo 0)" -lt 1000000000 ]; then
    echo "  Downloading epiCRealismXL VXVII CrystalClear..."
    if [ -n "$CIVITAI_TOKEN" ]; then
        wget -q --show-progress -c \
            --header="Authorization: Bearer $CIVITAI_TOKEN" \
            "https://civitai.com/api/download/models/847189" \
            -O "$SDXL_CKPT" || echo "  epiCRealismXL download FAILED (check CIVITAI_TOKEN or upload manually)"
    else
        # Try anonymous download first
        wget -q --show-progress -c \
            "https://civitai.com/api/download/models/847189" \
            -O "$SDXL_CKPT" || echo "  epiCRealismXL requires CIVITAI_TOKEN env var — set it or upload file manually"
    fi
    if [ -f "$SDXL_CKPT" ] && [ "$(stat -c%s "$SDXL_CKPT" 2>/dev/null || stat -f%z "$SDXL_CKPT" 2>/dev/null || echo 0)" -lt 1000000000 ]; then
        echo "  epiCRealismXL file too small — removing incomplete download"
        rm -f "$SDXL_CKPT"
    fi
else
    echo "  Already exists: (SDXL)_epiCRealismXL_VXVII_CrystalClear.safetensors"
fi

echo ""
echo "=== Model download complete ==="

# ============================================================
# Create symlinks from volume to ComfyUI model dirs
# ============================================================
link_dir() {
    local src_dir="$1"
    local dst_dir="$2"

    mkdir -p "$dst_dir"

    if [ ! -d "$src_dir" ]; then
        return
    fi

    for f in "$src_dir"/*; do
        [ -e "$f" ] || continue
        if [ -f "$f" ]; then
            ln -sf "$f" "$dst_dir/$(basename "$f")" 2>/dev/null || true
        elif [ -d "$f" ]; then
            # Recurse into subdirectories (e.g., ultralytics/bbox)
            link_dir "$f" "$dst_dir/$(basename "$f")"
        fi
    done
}

echo ""
echo "=== Linking models from volume ==="

# Standard model dirs
for dir in checkpoints vae loras unet clip clip_vision upscale_models controlnet embeddings sams; do
    link_dir "${MODELS_DIR}/${dir}" "${COMFYUI_DIR}/models/${dir}"
done

# Ultralytics (nested: bbox/)
link_dir "${MODELS_DIR}/ultralytics" "${COMFYUI_DIR}/models/ultralytics"

# New dirs for MrSmith v6 / Z-Image
link_dir "${MODELS_DIR}/diffusion_models" "${COMFYUI_DIR}/models/diffusion_models"
link_dir "${MODELS_DIR}/text_encoders" "${COMFYUI_DIR}/models/text_encoders"
link_dir "${MODELS_DIR}/SEEDVR2" "${COMFYUI_DIR}/models/SEEDVR2"

# Also check ComfyUI subdirectory layout on volume
if [ -d "${VOLUME_DIR}/ComfyUI/models" ]; then
    echo "Also linking from ${VOLUME_DIR}/ComfyUI/models/"
    for dir in checkpoints vae loras unet clip clip_vision upscale_models controlnet embeddings sams diffusion_models text_encoders; do
        link_dir "${VOLUME_DIR}/ComfyUI/models/${dir}" "${COMFYUI_DIR}/models/${dir}"
    done
    link_dir "${VOLUME_DIR}/ComfyUI/models/ultralytics" "${COMFYUI_DIR}/models/ultralytics"
fi

echo "Linking complete"

# ============================================================
# Model summary
# ============================================================
echo ""
echo "=== Model Summary ==="
echo "Checkpoints:      $(find ${COMFYUI_DIR}/models/checkpoints/ -maxdepth 1 -type f -o -type l 2>/dev/null | wc -l) files"
echo "VAE:              $(find ${COMFYUI_DIR}/models/vae/ -maxdepth 1 -type f -o -type l 2>/dev/null | wc -l) files"
echo "LoRAs:            $(find ${COMFYUI_DIR}/models/loras/ -type f -o -type l 2>/dev/null | wc -l) files"
echo "Diffusion Models: $(find ${COMFYUI_DIR}/models/diffusion_models/ -maxdepth 1 -type f -o -type l 2>/dev/null | wc -l) files"
echo "Text Encoders:    $(find ${COMFYUI_DIR}/models/text_encoders/ -maxdepth 1 -type f -o -type l 2>/dev/null | wc -l) files"
echo "SEEDVR2:          $(find ${COMFYUI_DIR}/models/SEEDVR2/ -maxdepth 1 -type f -o -type l 2>/dev/null | wc -l) files"
echo "Detection (bbox): $(find ${COMFYUI_DIR}/models/ultralytics/bbox/ -maxdepth 1 -type f -o -type l 2>/dev/null | wc -l) files"
echo "SAM:              $(find ${COMFYUI_DIR}/models/sams/ -maxdepth 1 -type f -o -type l 2>/dev/null | wc -l) files"
echo ""

echo "=== Starting Handler ==="
exec python /handler.py
