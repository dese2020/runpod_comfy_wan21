# ---- Stage 1: Build ----
#FROM runpod/worker-comfyui:5.5.0-base AS build
FROM runpod/worker-comfyui:5.5.0-base

# Variables de entorno
# setup CUDA env for torch & cpp extensions
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
ENV TORCH_CUDA_ARCH_LIST="8.9;9.0"

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
    curl ffmpeg ninja-build \
    && rm -rf /var/lib/apt/lists/*
	
# lightweight CUDA toolkit (includes nvcc, cublas, etc.)
RUN pip install --no-cache-dir \
    nvidia-cuda-runtime-cu12 \
    nvidia-cuda-nvcc-cu12 \
    nvidia-cublas-cu12

# Upgrade pip & install SageAttention
ENV TORCH_CUDA_ARCH_LIST="8.9"

RUN pip install --no-cache-dir --upgrade pip setuptools wheel
RUN python -m torch.utils.collect_env
RUN pip install --no-cache-dir ninja packaging
RUN pip install --no-cache-dir git+https://github.com/thu-ml/SageAttention.git

# Instalar SageAttention
#WORKDIR /
#RUN git clone https://github.com/thu-ml/SageAttention.git
#WORKDIR /SageAttention
#RUN sed -i "/compute_capabilities = set()/a compute_capabilities = {\"$TORCH_CUDA_ARCH_LIST\"}" setup.py
#RUN python setup.py install

# install custom nodes using comfy-cli
RUN comfy-node-install comfyui_ultimatesdupscale comfyui-kjnodes rgthree-comfy comfyui-videohelpersuite mikey_nodes comfyui-impact-pack comfyui-easy-use comfyui-florence2 comfyui_essentials cg-image-filter comfyui_layerstyle cg-use-everywhere comfyui-segment-anything-2 comfyui-frame-interpolation comfyui-detail-daemon ComfyUI-WanVideoWrapper comfyui-rmbg

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
	https://github.com/WASasquatch/was-node-suite-comfyui.git \
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
COPY handler.py /handler.py
COPY start.sh /start.sh
RUN chmod +x /start.sh

