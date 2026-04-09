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

# Clone all custom nodes
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git && \
    git clone https://github.com/jags111/efficiency-nodes-comfyui.git && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git && \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git && \
    git clone https://github.com/WASasquatch/was-node-suite-comfyui.git

# Install pip dependencies
RUN cd /comfyui/custom_nodes/ComfyUI-Impact-Pack && \
    pip install --no-cache-dir -r requirements.txt && \
    python install.py

RUN cd /comfyui/custom_nodes/ComfyUI-Impact-Subpack && \
    pip install --no-cache-dir -r requirements.txt

RUN cd /comfyui/custom_nodes/rgthree-comfy && \
    pip install --no-cache-dir -r requirements.txt

RUN cd /comfyui/custom_nodes/efficiency-nodes-comfyui && \
    pip install --no-cache-dir -r requirements.txt

RUN cd /comfyui/custom_nodes/ComfyUI_essentials && \
    pip install --no-cache-dir -r requirements.txt

RUN cd /comfyui/custom_nodes/ComfyUI-KJNodes && \
    pip install --no-cache-dir -r requirements.txt

RUN cd /comfyui/custom_nodes/was-node-suite-comfyui && \
    pip install --no-cache-dir -r requirements.txt
