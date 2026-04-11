FROM runpod/worker-comfyui:5.8.5-base

# Install custom nodes - only the 3 required packs
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/jags111/efficiency-nodes-comfyui.git && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git

# Install Impact Pack dependencies (install.py downloads subpack + pip deps)
RUN cd /comfyui/custom_nodes/ComfyUI-Impact-Pack && \
    pip install --no-cache-dir -r requirements.txt && \
    python install.py

# Install Efficiency Nodes dependencies
RUN cd /comfyui/custom_nodes/efficiency-nodes-comfyui && \
    pip install --no-cache-dir -r requirements.txt || true

# Configure model paths including ultralytics and sams for Impact Pack
RUN cat > /comfyui/extra_model_paths.yaml <<'YAML'
runpod_volume_root:
    base_path: /runpod-volume
    checkpoints: models/checkpoints/
    vae: models/vae/
    loras: models/loras/
    clip: models/clip/
    clip_vision: models/clip_vision/
    unet: models/unet/
    upscale_models: models/upscale_models/
    controlnet: models/controlnet/
    embeddings: models/embeddings/
    ultralytics: models/ultralytics/
    sams: models/sams/

network_volume:
    base_path: /runpod-volume/ComfyUI
    checkpoints: models/checkpoints/
    vae: models/vae/
    loras: models/loras/
    clip: models/clip/
    clip_vision: models/clip_vision/
    unet: models/unet/
    upscale_models: models/upscale_models/
    controlnet: models/controlnet/
    embeddings: models/embeddings/
    ultralytics: models/ultralytics/
    sams: models/sams/
YAML
