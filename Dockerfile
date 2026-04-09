FROM runpod/worker-comfyui:5.8.5-base

# Install custom nodes using comfy-cli (proper registration + dependency management)
RUN comfy node install --exit-on-fail efficiency-nodes-comfyui
RUN comfy node install --exit-on-fail rgthree-comfy
RUN comfy node install --exit-on-fail comfyui-impact-pack
RUN comfy node install --exit-on-fail comfyui-impact-subpack
RUN comfy node install --exit-on-fail comfyui_essentials
RUN comfy node install --exit-on-fail comfyui_jps-nodes
RUN comfy node install --exit-on-fail comfyui-kjnodes
RUN comfy node install --exit-on-fail was-node-suite-comfyui



# Trigger rebuild

# Add legacy GPU Pod model paths (network volume has models at /runpod-volume/ComfyUI/models/)
RUN printf '\nrunpod_legacy:\n    base_path: /runpod-volume/ComfyUI\n    checkpoints: models/checkpoints/\n    clip: models/clip/\n    clip_vision: models/clip_vision/\n    configs: models/configs/\n    controlnet: models/controlnet/\n    embeddings: models/embeddings/\n    loras: models/loras/\n    upscale_models: models/upscale_models/\n    vae: models/vae/\n    unet: models/unet/\n' >> /comfyui/extra_model_paths.yaml

