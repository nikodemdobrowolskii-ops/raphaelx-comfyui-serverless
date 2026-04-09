FROM runpod/worker-comfyui:5.5.0-base

# Install all custom nodes needed for imagegenerator_v2 workflow
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git && \
    git clone https://github.com/jags111/efficiency-nodes-comfyui.git && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git && \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git && \
    git clone https://github.com/ltdrdata/was-node-suite-comfyui.git

# Install pip dependencies for each custom node
RUN cd /comfyui/custom_nodes/ComfyUI-Impact-Pack && \
    pip install --no-cache-dir -r requirements.txt && \
    (python install.py || true)

RUN cd /comfyui/custom_nodes/rgthree-comfy && \
    (pip install --no-cache-dir -r requirements.txt || true)

RUN cd /comfyui/custom_nodes/efficiency-nodes-comfyui && \
    (pip install --no-cache-dir -r requirements.txt || true)

RUN cd /comfyui/custom_nodes/ComfyUI_essentials && \
    (pip install --no-cache-dir -r requirements.txt || true)

RUN cd /comfyui/custom_nodes/ComfyUI-KJNodes && \
    (pip install --no-cache-dir -r requirements.txt || true)

RUN cd /comfyui/custom_nodes/ComfyUI-Impact-Subpack && \
    (pip install --no-cache-dir -r requirements.txt || true)

RUN cd /comfyui/custom_nodes/was-node-suite-comfyui && \
    (pip install --no-cache-dir -r requirements.txt || true)
