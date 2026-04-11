FROM runpod/worker-comfyui:5.8.5-base

# Install custom nodes - only the 3 required packs
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/jags111/efficiency-nodes-comfyui.git && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git

# Install Impact Pack dependencies
RUN cd /comfyui/custom_nodes/ComfyUI-Impact-Pack && \
    pip install --no-cache-dir -r requirements.txt && \
    python install.py

# Install Efficiency Nodes dependencies
RUN cd /comfyui/custom_nodes/efficiency-nodes-comfyui && \
    pip install --no-cache-dir -r requirements.txt || true

# Download detection models (YOLO + SAM) directly into the image
RUN mkdir -p /comfyui/models/ultralytics/bbox /comfyui/models/sams && \
    wget -q -O /comfyui/models/ultralytics/bbox/face_yolov8m.pt \
      https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt && \
    wget -q -O /comfyui/models/ultralytics/bbox/hand_yolov8s.pt \
      https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt && \
    wget -q -O /comfyui/models/ultralytics/bbox/PitEyeDetailer-v2-seg.pt \
      https://huggingface.co/Outimus/Adetailer/resolve/main/PitEyeDetailer-v2-seg.pt && \
    wget -q -O /comfyui/models/ultralytics/bbox/pussyV2.pt \
      https://huggingface.co/art0123/Models_collection/resolve/main/bbox/pussyV2.pt && \
    wget -q -O /comfyui/models/sams/sam_vit_b_01ec64.pth \
      https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth

# Configure model paths
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
