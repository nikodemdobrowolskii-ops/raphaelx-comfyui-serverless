FROM runpod/worker-comfyui:5.8.5-base

# ============================================================
# MrSmith v6 Ultimate Edition — Custom Nodes for Serverless
# ============================================================

# Core nodes (required) — each clone isolated so one bad URL doesn't kill the build
# Disable git prompts so failed clones fail fast instead of blocking on auth prompt
ENV GIT_TERMINAL_PROMPT=0
ENV GIT_ASKPASS=/bin/echo

RUN cd /comfyui/custom_nodes && \
    for repo in \
      "https://github.com/rgthree/rgthree-comfy.git" \
      "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git" \
      "https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git" \
      "https://github.com/kijai/ComfyUI-KJNodes.git" \
      "https://github.com/WASasquatch/was-node-suite-comfyui.git" \
      "https://github.com/jags111/efficiency-nodes-comfyui.git" \
      "https://github.com/cubiq/ComfyUI_essentials.git" \
      "https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git" \
      "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git" \
      "https://github.com/city96/ComfyUI-GGUF.git" \
      "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git" \
      "https://github.com/ltdrdata/ComfyUI-Manager.git" \
      "https://github.com/chrisgoringe/cg-use-everywhere.git" \
      "https://github.com/kijai/ComfyUI-SeedVR2Wrapper.git" \
      "https://github.com/yolain/ComfyUI-Easy-Use.git" \
      "https://github.com/sipherxyz/comfyui-art-venture.git" \
      "https://github.com/gseth/ControlAltAI-Nodes.git" ; do \
      name=$(basename "$repo" .git) ; \
      echo "=== Cloning $name ===" ; \
      git clone --depth 1 "$repo" || echo "WARN: clone failed for $repo" ; \
    done

# Install Impact Pack dependencies (downloads subpack models + pip deps)
RUN cd /comfyui/custom_nodes/ComfyUI-Impact-Pack && \
    pip install --no-cache-dir -r requirements.txt && \
    python install.py

# Install dependencies for all nodes that have requirements.txt
RUN for dir in /comfyui/custom_nodes/*/; do \
      if [ -f "$dir/requirements.txt" ]; then \
        echo "Installing deps for $(basename $dir)..." && \
        pip install --no-cache-dir -r "$dir/requirements.txt" || echo "WARN: deps failed for $(basename $dir)"; \
      fi; \
    done

# Run install.py for nodes that have it (skip Impact Pack — already done)
RUN for dir in /comfyui/custom_nodes/*/; do \
      if [ -f "$dir/install.py" ] && [ "$(basename $dir)" != "ComfyUI-Impact-Pack" ]; then \
        echo "Running install.py for $(basename $dir)..." && \
        cd "$dir" && python install.py 2>/dev/null || echo "WARN: install.py failed for $(basename $dir)"; \
      fi; \
    done

# Install GGUF support (needed for SeedVR2 Q4 GGUF model)
RUN pip install --no-cache-dir gguf

# ============================================================
# Model paths — network volume + new model types
# ============================================================
RUN cat > /comfyui/extra_model_paths.yaml <<'YAML'
# Models on network volume (mounted at /runpod-volume)
# Supports both /runpod-volume/models/ and /runpod-volume/ComfyUI/models/ layouts
runpod_volume_root:
    base_path: /runpod-volume/models
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
    diffusion_models: diffusion_models/
    text_encoders: text_encoders/

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
    diffusion_models: diffusion_models/
    text_encoders: text_encoders/

# SeedVR2 models
seedvr2:
    base_path: /runpod-volume/models/SEEDVR2
    diffusion_models: ./
    vae: ./
YAML

# Copy startup script and handler
COPY start.sh /start.sh
RUN chmod +x /start.sh

COPY handler.py /handler.py

# Use our startup script as entrypoint
CMD ["/start.sh"]
