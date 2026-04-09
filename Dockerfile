FROM runpod/worker-comfyui:5.5.0-base

# Install custom nodes using comfy-cli (proper registration + dependency management)
RUN comfy node install --exit-on-fail efficiency-nodes-comfyui
RUN comfy node install --exit-on-fail rgthree-comfy
RUN comfy node install --exit-on-fail comfyui-impact-pack
RUN comfy node install --exit-on-fail comfyui-impact-subpack
RUN comfy node install --exit-on-fail comfyui_essentials
RUN comfy node install --exit-on-fail comfyui_jps-nodes
RUN comfy node install --exit-on-fail comfyui-kjnodes
RUN comfy node install --exit-on-fail was-node-suite-comfyui
