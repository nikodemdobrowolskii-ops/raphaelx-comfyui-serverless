# RunPod Serverless Docker Image for ComfyUI with Custom Nodes
# Base: RunPod PyTorch with CUDA 12.4
FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV COMFYUI_DIR=/workspace/ComfyUI
ENV PYTHONUNBUFFERED=1

# System dependencies
RUN apt-get update && apt-get install -y \
    git wget curl \
    libgl1-mesa-glx libglib2.0-0 libsm6 libxext6 libxrender-dev \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git ${COMFYUI_DIR} && \
    cd ${COMFYUI_DIR} && \
    pip install --no-cache-dir -r requirements.txt

# ============================================================
# Custom Nodes Installation
# ============================================================

WORKDIR ${COMFYUI_DIR}/custom_nodes

# rgthree-comfy: Bus Node, Lora Loader Stack, Power Lora Loader, Image Comparer
RUN git clone https://github.com/rgthree/rgthree-comfy.git && \
    cd rgthree-comfy && \
    (pip install --no-cache-dir -r requirements.txt 2>/dev/null || true)

# ComfyUI-Impact-Pack: FaceDetailer, FaceDetailerPipe, UltralyticsDetectorProvider,
# SAMLoader, ToDetailerPipeSDXL, BboxDetectorSEGS, ImpactGaussianBlurMask
RUN git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git && \
    cd ComfyUI-Impact-Pack && \
    pip install --no-cache-dir -r requirements.txt && \
    python install.py

# ComfyUI-Impact-Subpack (dependency of Impact-Pack)
RUN git clone https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git && \
    cd ComfyUI-Impact-Subpack && \
    (pip install --no-cache-dir -r requirements.txt 2>/dev/null || true)

# efficiency-nodes-comfyui: KSampler (Efficient)
RUN git clone https://github.com/jags111/efficiency-nodes-comfyui.git && \
    cd efficiency-nodes-comfyui && \
    (pip install --no-cache-dir -r requirements.txt 2>/dev/null || true)

# ComfyUI_essentials: SelfAttentionGuidance and other utility nodes
RUN git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    cd ComfyUI_essentials && \
    (pip install --no-cache-dir -r requirements.txt 2>/dev/null || true)

# ComfyUI-SeedVR2Wrapper
RUN git clone https://github.com/kijai/ComfyUI-SeedVR2Wrapper.git && \
    cd ComfyUI-SeedVR2Wrapper && \
    (pip install --no-cache-dir -r requirements.txt 2>/dev/null || true)

# ComfyUI_JPS-Nodes: Multiply Int Float (JPS)
RUN git clone https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git && \
    (cd ComfyUI_JPS-Nodes && pip install --no-cache-dir -r requirements.txt 2>/dev/null || true)

# ComfyUI-KJNodes
RUN git clone https://github.com/kijai/ComfyUI-KJNodes.git && \
    cd ComfyUI-KJNodes && \
    (pip install --no-cache-dir -r requirements.txt 2>/dev/null || true)

# ComfyUI-Tiling (for upscaler)
RUN git clone https://github.com/city96/ComfyUI-Tiling.git || \
    echo "WARNING: ComfyUI-Tiling clone failed"

# LG_Noise node
RUN git clone https://github.com/lquesada/ComfyUI-LG-Noise.git || \
    echo "WARNING: ComfyUI-LG-Noise clone failed"

# Inpaint-CropAndStitch (for faceswap workflow)
RUN git clone https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git || \
    echo "WARNING: Inpaint-CropAndStitch clone failed"

# TeaCache optimization (for faceswap workflow)
RUN git clone https://github.com/welltop-cn/ComfyUI-TeaCache.git && \
    (cd ComfyUI-TeaCache && pip install --no-cache-dir -r requirements.txt || true) || \
    echo "WARNING: ComfyUI-TeaCache clone failed"

# was-node-suite for ImageConcanate and utility nodes
RUN git clone https://github.com/WASasquatch/was-node-suite-comfyui.git && \
    (cd was-node-suite-comfyui && pip install --no-cache-dir -r requirements.txt || true)

# ComfyUI-Manager
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git

# ============================================================
# Python Dependencies
# ============================================================

RUN pip install --no-cache-dir \
    runpod \
    boto3 \
    websocket-client \
    requests

# ============================================================
# Model directories setup
# ============================================================

RUN mkdir -p ${COMFYUI_DIR}/models/checkpoints \
    ${COMFYUI_DIR}/models/vae \
    ${COMFYUI_DIR}/models/loras \
    ${COMFYUI_DIR}/models/unet \
    ${COMFYUI_DIR}/models/clip \
    ${COMFYUI_DIR}/models/upscale_models \
    ${COMFYUI_DIR}/models/ultralytics/bbox \
    ${COMFYUI_DIR}/models/sams \
    ${COMFYUI_DIR}/input \
    ${COMFYUI_DIR}/output

WORKDIR /workspace

# Copy handler and startup script
COPY start.sh /start.sh
COPY handler.py /handler.py

RUN chmod +x /start.sh

CMD ["/start.sh"]
