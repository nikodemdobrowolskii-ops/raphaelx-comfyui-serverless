FROM runpod/worker-comfyui:5.8.5-base

# Override extra_model_paths.yaml to point to our network volume structure
RUN cat > /comfyui/extra_model_paths.yaml <<'YAML'
docker_image:
  base_path: /comfyui
  checkpoints: models/checkpoints/
  clip: models/clip/
  clip_vision: models/clip_vision/
  configs: models/configs/
  controlnet: models/controlnet/
  embeddings: models/embeddings/
  loras: models/loras/
  upscale_models: models/upscale_models/
  vae: models/vae/
  unet: models/unet/

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
  ultralytics: ultralytics/
  sams: sams/
YAML

# Install critical missing dependency
RUN pip install --no-cache-dir simpleeval

# Clone custom nodes (skip if already exists in base image)
RUN cd /comfyui/custom_nodes && \
    (git clone https://github.com/rgthree/rgthree-comfy.git || true) && \
    (git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git || true) && \
    (git clone https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git || true) && \
    (git clone https://github.com/jags111/efficiency-nodes-comfyui.git || true) && \
    (git clone https://github.com/cubiq/ComfyUI_essentials.git || true) && \
    (git clone https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git || true) && \
    (git clone https://github.com/kijai/ComfyUI-KJNodes.git || true) && \
    (git clone https://github.com/WASasquatch/was-node-suite-comfyui.git || true)

# Install pip dependencies for each custom node
RUN cd /comfyui/custom_nodes/ComfyUI-Impact-Pack && \
    pip install --no-cache-dir -r requirements.txt && \
    python install.py || true

RUN cd /comfyui/custom_nodes/ComfyUI-Impact-Subpack && \
    pip install --no-cache-dir -r requirements.txt || true

RUN cd /comfyui/custom_nodes/rgthree-comfy && \
    pip install --no-cache-dir -r requirements.txt || true

RUN cd /comfyui/custom_nodes/efficiency-nodes-comfyui && \
    pip install --no-cache-dir -r requirements.txt || true

RUN cd /comfyui/custom_nodes/ComfyUI_essentials && \
    pip install --no-cache-dir -r requirements.txt || true

RUN cd /comfyui/custom_nodes/ComfyUI-KJNodes && \
    pip install --no-cache-dir -r requirements.txt || true

RUN cd /comfyui/custom_nodes/was-node-suite-comfyui && \
    pip install --no-cache-dir -r requirements.txt || true
