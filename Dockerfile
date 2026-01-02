# --- SCAIL Video Motion Transfer - RunPod Serverless ---
# Based on: https://github.com/kijai/ComfyUI-WanVideoWrapper
# GPU: H100 (80GB VRAM) | Model: BF16 (Full quality)

FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ="Etc/UTC"
ENV COMFYUI_PATH=/root/comfy/ComfyUI
ENV VENV_PATH=/venv

# --- 1. Install System Dependencies ---
RUN apt-get update && apt-get install -y \
    curl \
    git \
    git-lfs \
    ffmpeg \
    wget \
    unzip \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# --- 2. Setup Python Virtual Environment ---
RUN python -m venv $VENV_PATH
ENV PATH="$VENV_PATH/bin:$PATH"
RUN /venv/bin/python -m pip install --upgrade pip

# --- 3. Install ComfyUI ---
RUN /venv/bin/python -m pip install comfy-cli
RUN comfy --skip-prompt install --nvidia --cuda-version 12.4

# --- 4. Install Core Python Dependencies ---
RUN /venv/bin/python -m pip install \
    runpod \
    requests \
    websocket-client \
    boto3 \
    huggingface-hub

# --- 5. Create Model Directories ---
RUN mkdir -p \
    $COMFYUI_PATH/models/diffusion_models \
    $COMFYUI_PATH/models/text_encoders \
    $COMFYUI_PATH/models/vae \
    $COMFYUI_PATH/models/clip_vision \
    $COMFYUI_PATH/models/loras \
    $COMFYUI_PATH/models/detection \
    $COMFYUI_PATH/models/controlnet

# --- 6. Clone Custom Nodes ---
# Main SCAIL nodes
RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI-WanVideoWrapper

RUN git clone https://github.com/kijai/ComfyUI-KJNodes.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI-KJNodes

RUN git clone https://github.com/kijai/ComfyUI-SCAIL-Pose.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI-SCAIL-Pose

RUN git clone https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI-WanAnimatePreprocess

# Utility nodes for video I/O and pose detection
RUN git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
    $COMFYUI_PATH/custom_nodes/ComfyUI-VideoHelperSuite

RUN git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git \
    $COMFYUI_PATH/custom_nodes/comfyui_controlnet_aux

# --- 7. Install Custom Node Requirements ---
# WanVideoWrapper requirements
RUN /venv/bin/python -m pip install \
    ftfy \
    accelerate>=1.2.1 \
    einops \
    diffusers>=0.33.0 \
    peft>=0.17.0 \
    sentencepiece>=0.2.0 \
    protobuf \
    pyloudnorm \
    gguf>=0.17.1 \
    opencv-python \
    scipy

# VideoHelperSuite requirements
RUN /venv/bin/python -m pip install \
    imageio-ffmpeg

# KJNodes requirements
RUN /venv/bin/python -m pip install \
    pillow>=10.3.0 \
    color-matcher \
    matplotlib \
    mss

# ControlNet Aux requirements
RUN /venv/bin/python -m pip install \
    scikit-image \
    mediapipe \
    fvcore \
    yapf \
    omegaconf \
    addict \
    yacs \
    trimesh[easy] \
    albumentations \
    scikit-learn

# --- 8. Download SCAIL Model (BF16 - Full Quality) ---
# Main diffusion model (~28GB)
RUN /venv/bin/huggingface-cli download Kijai/WanVideo_comfy \
    SCAIL/Wan21-14B-SCAIL-preview_comfy_bf16.safetensors \
    --local-dir $COMFYUI_PATH/models/diffusion_models \
    --local-dir-use-symlinks False

# --- 9. Download Text Encoder ---
RUN /venv/bin/huggingface-cli download Kijai/WanVideo_comfy \
    umt5xxl_fp16.safetensors \
    --local-dir $COMFYUI_PATH/models/text_encoders \
    --local-dir-use-symlinks False

# --- 10. Download VAE ---
RUN /venv/bin/huggingface-cli download Kijai/WanVideo_comfy \
    Wan2_1_VAE_bf16.safetensors \
    --local-dir $COMFYUI_PATH/models/vae \
    --local-dir-use-symlinks False

# --- 11. Download CLIP Vision ---
RUN /venv/bin/huggingface-cli download Comfy-Org/Wan_2.1_ComfyUI_repackaged \
    split_files/clip_vision/clip_vision_h.safetensors \
    --local-dir $COMFYUI_PATH/models/clip_vision \
    --local-dir-use-symlinks False

# Move clip vision file to correct location
RUN mv $COMFYUI_PATH/models/clip_vision/split_files/clip_vision/* $COMFYUI_PATH/models/clip_vision/ 2>/dev/null || true
RUN rm -rf $COMFYUI_PATH/models/clip_vision/split_files 2>/dev/null || true

# --- 12. Download LoRAs (Lightx2v) ---
RUN /venv/bin/huggingface-cli download Kijai/WanVideo_comfy \
    Lightx2v/lightx2v_wan2.1_lora_bf16.safetensors \
    --local-dir $COMFYUI_PATH/models/loras \
    --local-dir-use-symlinks False

# Move lora file to correct location
RUN mv $COMFYUI_PATH/models/loras/Lightx2v/* $COMFYUI_PATH/models/loras/ 2>/dev/null || true
RUN rm -rf $COMFYUI_PATH/models/loras/Lightx2v 2>/dev/null || true

# --- 13. Download ONNX Detection Models ---
# ViTPose wholebody
RUN /venv/bin/huggingface-cli download JunkyByte/easy_ViTPose \
    onnx/wholebody/vitpose-h-wholebody.onnx \
    --local-dir $COMFYUI_PATH/models/detection \
    --local-dir-use-symlinks False

# Wan2.2-Animate detection model
RUN /venv/bin/huggingface-cli download Wan-AI/Wan2.2-Animate-14B \
    process_checkpoint/det/yolox_l_8xb8-300e_coco_20211126_140236-d3bd2b23.pth \
    --local-dir $COMFYUI_PATH/models/detection \
    --local-dir-use-symlinks False

# --- 14. Download Uni3C ControlNet ---
RUN /venv/bin/huggingface-cli download Kijai/WanVideo_comfy \
    Wan21_Uni3C_controlnet_fp16.safetensors \
    --local-dir $COMFYUI_PATH/models/controlnet \
    --local-dir-use-symlinks False

# --- 15. Copy Handler Scripts ---
COPY src/start.sh /root/start.sh
COPY src/rp_handler.py /root/rp_handler.py
COPY src/ComfyUI_API_Wrapper.py /root/ComfyUI_API_Wrapper.py

RUN chmod +x /root/start.sh

# --- 16. Start Container ---
CMD ["/root/start.sh"]
