FROM runpod/worker-comfyui:5.8.5-base

RUN cat > /comfyui/extra_model_paths.yaml <<'YAML'
network_volume:
    base_path: /runpod-volume/ComfyUI/models
    checkpoints: checkpoints/
    vae: vae/
    loras: loras/
    clip: clip/
    clip_vision: clip_vision/
    unet: unet/
    upscale_models: upscale_models/
    controlnet: controlnet/
    embeddings: embeddings/
YAML
