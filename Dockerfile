# ---- Stage 1: Build ----
FROM runpod/worker-comfyui:5.5.0-base AS build

# Variables de entorno
ENV COMFY_USE_SAGEATTN=1
ENV PATH=/usr/local/cuda/bin:$PATH
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    cmake \
    gcc \
    g++ \
    make \
    python3-dev \
    libcairo2-dev \
    libffi-dev \
    libssl-dev \
    git \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip & install SageAttention
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Instalar SageAttention
RUN pip install --no-cache-dir sageattention

# install custom nodes using comfy-cli
RUN comfy-node-install comfyui_ultimatesdupscale comfyui-kjnodes rgthree-comfy comfyui-videohelpersuite mikey_nodes comfyui-impact-pack comfyui-easy-use comfyui-florence2 was-node-suite-comfyui comfyui_essentials cg-image-filter comfyui_layerstyle cg-use-everywhere comfyui-segment-anything-2 comfyui-frame-interpolation comfyui-detail-daemon ComfyUI-WanVideoWrapper comfyui-rmbg

RUN for repo in \
    https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git \
    https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git \
    https://github.com/Jordach/comfy-plasma.git \
    https://github.com/ShmuelRonen/ComfyUI-LatentSyncWrapper.git \
    https://github.com/ClownsharkBatwing/RES4LYF \
    https://github.com/chflame163/ComfyUI_LayerStyle_Advance.git \
    https://github.com/BadCafeCode/masquerade-nodes-comfyui.git \
	https://github.com/welltop-cn/ComfyUI-TeaCache.git \
	https://github.com/Fannovel16/comfyui_controlnet_aux.git \
	https://github.com/theUpsider/ComfyUI-Logic.git \
    https://github.com/M1kep/ComfyLiterals.git; \
    do \
        cd /comfyui/custom_nodes; \
        repo_dir=$(basename "$repo" .git); \
        if [ "$repo" = "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git" ]; then \
            git clone --recursive "$repo"; \
        else \
            git clone "$repo"; \
        fi; \
        if [ -f "/comfyui/custom_nodes/$repo_dir/requirements.txt" ]; then \
            pip install --no-cache-dir -r "/comfyui/custom_nodes/$repo_dir/requirements.txt"; \
        fi; \
        if [ -f "/comfyui/custom_nodes/$repo_dir/install.py" ]; then \
            python "/comfyui/custom_nodes/$repo_dir/install.py"; \
        fi; \
    done

# Download models
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors --relative-path models/clip --filename umt5_xxl_fp8_e4m3fn_scaled.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors --relative-path models/vae --filename wan_2.1_vae.safetensors
#RUN comfy model download --url https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_CausVid_14B_T2V_lora_rank32.safetensors --relative-path models/loras --filename Wan21_CausVid_14B_T2V_lora_rank32.safetensors
#RUN comfy model download --url https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors --relative-path models/loras --filename Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors
#RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_t2v_14B_bf16.safetensors --relative-path models/diffusion_models --filename wan2.1_t2v_14B_bf16.safetensors

COPY 4xLSDIR.pth /comfyui/models/upscale_models/4xLSDIR.pth
COPY handler.py /runpod/handler.py
COPY start.sh /start.sh

# ---- Stage 2: Final ----
FROM runpod/worker-comfyui:5.5.0-base

ENV COMFY_USE_SAGEATTN=1
ENV PATH=/usr/local/cuda/bin:$PATH
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH

# Copy custom nodes and models from build stage
COPY --from=build /comfyui /comfyui

# Copy only the required Python packages (SageAttention + dependencies)
COPY --from=build /usr/local/lib/python3.12/site-packages/sageattention* /usr/local/lib/python3.12/site-packages/
#COPY --from=build /usr/local/lib/python3.12/site-packages/triton /usr/local/lib/python3.12/site-packages/triton
COPY --from=build /usr/local/lib/python3.12/site-packages/torch* /usr/local/lib/python3.12/site-packages/
COPY --from=build /usr/local/lib/python3.12/site-packages/typing_extensions* /usr/local/lib/python3.12/site-packages/

# Copy handler
COPY --from=build /runpod/handler.py /runpod/handler.py
COPY --from=build /start.sh /start.sh
RUN chmod +x /start.sh
