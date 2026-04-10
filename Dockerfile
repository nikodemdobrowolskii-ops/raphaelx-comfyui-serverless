FROM runpod/worker-comfyui:5.8.5-base

# ============================================================
# Override extra_model_paths.yaml to point to our network volume structure.
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
YAML

# ============================================================
# Download ultralytics detection models + SAM into the image
# These models lived only in the old Pod container, NOT on the
# network volume, so we bake them into the Docker image.
# ============================================================
RUN mkdir -p /comfyui/models/ultralytics/bbox /comfyui/models/sams

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

# Install pip dependencies - NO || true, let failures be visible
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
FROM runpod/worker-comfyui:5.8.5-base

# Override extra_model_paths.yaml for network volume
RUN cat > /comfyui/extra_model_paths.yaml <<'YAML'
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
YAML

# Create a custom node that registers ultralytics/sams model paths
# This runs inside ComfyUI Python process and is the most reliable method
RUN mkdir -p /comfyui/custom_nodes/raphaelx_model_paths
RUN cat > /comfyui/custom_nodes/raphaelx_model_paths/__init__.py <<'PYEOF'
import folder_paths
import os

# Register ultralytics model paths from network volume
VOLUME_PATHS = [
    "/runpod-volume/ComfyUI/models",
    "/runpod-volume/models",
]

for base in VOLUME_PATHS:
    ul_path = os.path.join(base, "ultralytics")
    if os.path.isdir(ul_path):
        folder_paths.add_model_folder_path("ultralytics", ul_path)
        print(f"[RaphaelX] Registered ultralytics path: {ul_path}")
        # List what we found
        for root, dirs, files in os.walk(ul_path):
            for f in files:
                rel = os.path.relpath(os.path.join(root, f), ul_path)
                print(f"[RaphaelX]   Found: {rel}")

    sams_path = os.path.join(base, "sams")
    if os.path.isdir(sams_path):
        folder_paths.add_model_folder_path("sams", sams_path)
        print(f"[RaphaelX] Registered sams path: {sams_path}")

NODE_CLASS_MAPPINGS = {}
PYEOF

# Install critical missing dependency
RUN pip install --no-cache-dir simpleeval

# Clone all custom nodes
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
FROM runpod/worker-comfyui:5.8.5-base

# Override extra_model_paths.yaml for network volume model paths
RUN cat > /comfyui/extra_model_paths.yaml <<'YAML'
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
    ultralytics_bbox: models/ultralytics/bbox/
    ultralytics_segm: models/ultralytics/segm/
    ultralytics: models/ultralytics/
    sams: models/sams/
YAML

# Create startup wrapper that symlinks ultralytics/sams models at runtime
RUN cat > /start.sh <<'STARTSH'
#!/bin/bash
echo "[RaphaelX] Creating model symlinks from network volume..."

if [ -d "/runpod-volume/ComfyUI/models/ultralytics" ]; then
    mkdir -p /comfyui/models/ultralytics
    for subdir in bbox segm; do
        if [ -d "/runpod-volume/ComfyUI/models/ultralytics/$subdir" ]; then
            ln -sfn "/runpod-volume/ComfyUI/models/ultralytics/$subdir" "/comfyui/models/ultralytics/$subdir"
            echo "[RaphaelX] Linked ultralytics/$subdir"
        fi
    done
fi

if [ -d "/runpod-volume/ComfyUI/models/sams" ]; then
    mkdir -p /comfyui/models/sams
    for f in /runpod-volume/ComfyUI/models/sams/*; do
        [ -f "$f" ] && ln -sfn "$f" "/comfyui/models/sams/$(basename $f)"
    done
    echo "[RaphaelX] Linked sams models"
fi

echo "[RaphaelX] Starting worker..."
exec /entrypoint.sh "$@"
STARTSH
RUN chmod +x /start.sh

ENTRYPOINT ["/start.sh"]

# Install critical missing dependency
RUN pip install --no-cache-dir simpleeval

# Clone all custom nodes
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
FROM runpod/worker-comfyui:5.8.5-base

# ============================================================
# Override extra_model_paths.yaml to point to our network volume structure.
# ============================================================
RUN cat > /comfyui/extra_model_paths.yaml <<'YAML'
# Section 1: base image default
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

# Section 2: Network Volume "Modelka"
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

# Section 3: Ultralytics/YOLO + SAM models (Impact Pack)
network_volume_detection:
    base_path: /runpod-volume/ComfyUI/models
    ultralytics_bbox: ultralytics/bbox/
    ultralytics_segm: ultralytics/segm/
    ultralytics: ultralytics/
    sams: sams/
YAML

# Install critical missing dependency
RUN pip install --no-cache-dir simpleeval

# Clone all custom nodes
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
