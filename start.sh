#!/bin/bash
# RunPod Serverless Startup Script
# Creates symlinks from network volume to ComfyUI model directories
# then starts the handler

set -e

COMFYUI_DIR="${COMFYUI_DIR:-/workspace/ComfyUI}"
VOLUME_DIR="/runpod-volume"

echo "=== RunPod Serverless Startup ==="
echo "ComfyUI dir: ${COMFYUI_DIR}"
echo "Volume dir: ${VOLUME_DIR}"

# Create model directories if they don't exist
mkdir -p "${COMFYUI_DIR}/models/checkpoints"
mkdir -p "${COMFYUI_DIR}/models/vae"
mkdir -p "${COMFYUI_DIR}/models/loras"
mkdir -p "${COMFYUI_DIR}/models/unet"
mkdir -p "${COMFYUI_DIR}/models/clip"
mkdir -p "${COMFYUI_DIR}/models/upscale_models"
mkdir -p "${COMFYUI_DIR}/models/ultralytics/bbox"
mkdir -p "${COMFYUI_DIR}/models/sams"
mkdir -p "${COMFYUI_DIR}/input"
mkdir -p "${COMFYUI_DIR}/output"

# Link models from network volume if available
if [ -d "${VOLUME_DIR}/models" ]; then
    echo "Network volume detected at ${VOLUME_DIR}/models"

    # Symlink checkpoint models
    if [ -d "${VOLUME_DIR}/models/checkpoints" ]; then
        for f in "${VOLUME_DIR}/models/checkpoints"/*; do
            [ -f "$f" ] || continue
            ln -sf "$f" "${COMFYUI_DIR}/models/checkpoints/$(basename "$f")" 2>/dev/null || true
            echo "  Linked checkpoint: $(basename "$f")"
        done
    fi

    # Symlink VAE models
    if [ -d "${VOLUME_DIR}/models/vae" ]; then
        for f in "${VOLUME_DIR}/models/vae"/*; do
            [ -f "$f" ] || continue
            ln -sf "$f" "${COMFYUI_DIR}/models/vae/$(basename "$f")" 2>/dev/null || true
            echo "  Linked VAE: $(basename "$f")"
        done
    fi

    # Symlink LoRA models
    if [ -d "${VOLUME_DIR}/models/loras" ]; then
        for f in "${VOLUME_DIR}/models/loras"/*; do
            [ -f "$f" ] || continue
            ln -sf "$f" "${COMFYUI_DIR}/models/loras/$(basename "$f")" 2>/dev/null || true
            echo "  Linked LoRA: $(basename "$f")"
        done
    fi

    # Symlink UNET models
    if [ -d "${VOLUME_DIR}/models/unet" ]; then
        for f in "${VOLUME_DIR}/models/unet"/*; do
            [ -f "$f" ] || continue
            ln -sf "$f" "${COMFYUI_DIR}/models/unet/$(basename "$f")" 2>/dev/null || true
            echo "  Linked UNET: $(basename "$f")"
        done
    fi

    # Symlink CLIP models
    if [ -d "${VOLUME_DIR}/models/clip" ]; then
        for f in "${VOLUME_DIR}/models/clip"/*; do
            [ -f "$f" ] || continue
            ln -sf "$f" "${COMFYUI_DIR}/models/clip/$(basename "$f")" 2>/dev/null || true
            echo "  Linked CLIP: $(basename "$f")"
        done
    fi

    # Symlink upscale models
    if [ -d "${VOLUME_DIR}/models/upscale_models" ]; then
        for f in "${VOLUME_DIR}/models/upscale_models"/*; do
            [ -f "$f" ] || continue
            ln -sf "$f" "${COMFYUI_DIR}/models/upscale_models/$(basename "$f")" 2>/dev/null || true
            echo "  Linked upscale model: $(basename "$f")"
        done
    fi

    # Symlink ultralytics detection models
    if [ -d "${VOLUME_DIR}/models/ultralytics/bbox" ]; then
        for f in "${VOLUME_DIR}/models/ultralytics/bbox"/*; do
            [ -f "$f" ] || continue
            ln -sf "$f" "${COMFYUI_DIR}/models/ultralytics/bbox/$(basename "$f")" 2>/dev/null || true
            echo "  Linked detection model: $(basename "$f")"
        done
    fi

    # Symlink SAM models
    if [ -d "${VOLUME_DIR}/models/sams" ]; then
        for f in "${VOLUME_DIR}/models/sams"/*; do
            [ -f "$f" ] || continue
            ln -sf "$f" "${COMFYUI_DIR}/models/sams/$(basename "$f")" 2>/dev/null || true
            echo "  Linked SAM model: $(basename "$f")"
        done
    fi

    echo "Network volume linking complete"
else
    echo "WARNING: No network volume found at ${VOLUME_DIR}"
    echo "Models must be baked into the Docker image or downloaded at runtime"
fi

# List linked models for verification
echo ""
echo "=== Model Summary ==="
echo "Checkpoints: $(ls ${COMFYUI_DIR}/models/checkpoints/ 2>/dev/null | wc -l) files"
echo "VAE: $(ls ${COMFYUI_DIR}/models/vae/ 2>/dev/null | wc -l) files"
echo "LoRAs: $(ls ${COMFYUI_DIR}/models/loras/ 2>/dev/null | wc -l) files"
echo "UNET: $(ls ${COMFYUI_DIR}/models/unet/ 2>/dev/null | wc -l) files"
echo "CLIP: $(ls ${COMFYUI_DIR}/models/clip/ 2>/dev/null | wc -l) files"
echo "Upscale: $(ls ${COMFYUI_DIR}/models/upscale_models/ 2>/dev/null | wc -l) files"
echo "Detection: $(ls ${COMFYUI_DIR}/models/ultralytics/bbox/ 2>/dev/null | wc -l) files"
echo "SAM: $(ls ${COMFYUI_DIR}/models/sams/ 2>/dev/null | wc -l) files"
echo ""

echo "=== Starting Handler ==="
exec python /handler.py
