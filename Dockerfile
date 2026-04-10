FROM runpod/worker-comfyui:5.8.5-base

# ============================================================
# Override extra_model_paths.yaml to point to our network volume structure
# AND to the baked-in detection models inside the image.
# ============================================================
RUN cat > /comfyui/extra_model_paths.yaml <<'YAML'
# Section 1: Keep the base image default (models baked into the image)
runpod_worker_comfy:
    base_path: /runpod-volume
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

# Section 2: Models on Network Volume "Modelka" (actual structure)
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
    configs: models/configs/

# Section 3: Detection models baked into the Docker image
# Impact Pack needs ultralytics + sams folder types registered
baked_detection_models:
    base_path: /comfyui/models
    ultralytics_bbox: ultralytics/bbox/
    ultralytics_segm: ultralytics/segm/
    ultralytics: ultralytics/
    sams: sams/
YAML

# ============================================================
# Download ultralytics detection models + SAM into the image
# These models lived only in the old Pod container, NOT on the
# network volume, so we bake them into the Docker image.
# ============================================================
RUN mkdir -p /comfyui/models/ultralytics/bbox /comfyui/models/ultralytics/segm /comfyui/models/sams

# Face detection model for FaceDetailer (~52MB)
RUN wget -q -O /comfyui/models/ultralytics/bbox/face_yolov8m.pt \
    https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt

# Hand detection model (~22MB)
RUN wget -q -O /comfyui/models/ultralytics/bbox/hand_yolov8s.pt \
    https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt

# SAM model for segmentation (~375MB)
RUN wget -q -O /comfyui/models/sams/sam_vit_b_01ec64.pth \
    https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth

# Install critical missing dependency first
RUN pip install --no-cache-dir simpleeval

# Clone all custom nodes (|| true to handle already-existing dirs in base image)
RUN cd /comfyui/custom_nodes && \
    (git clone https://github.com/rgthree/rgthree-comfy.git || true) && \
    (git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git || true) && \
    (git clone https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git || true) && \
    (git clone https://github.com/jags111/efficiency-nodes-comfyui.git || true) && \
    (git clone https://github.com/ltdrdata/ComfyUI-Manager.git || true) && \
    (git clone https://github.com/cubiq/ComfyUI_essentials.git || true) && \
    (git clone https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git || true) && \
    (git clone https://github.com/kijai/ComfyUI-KJNodes.git || true) && \
    (git clone https://github.com/WASasquatch/was-node-suite-comfyui.git || true)

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
