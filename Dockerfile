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

# --- 8. Network Volume Model Setup ---
# Models are pre-downloaded to /runpod-volume/models on the Network Volume
# At runtime, start.sh creates symlinks from ComfyUI model folders to the volume
# This avoids 60GB+ downloads during build and enables fast deployments
#
# Expected Network Volume structure:
#   /runpod-volume/models/
#     ├── diffusion_models/  (SCAIL 14B BF16 - 31GB)
#     ├── text_encoders/     (umt5-xxl - 11GB)
#     ├── vae/               (Wan2.1 VAE - 245MB)
#     ├── clip_vision/       (clip_vision_h - 1.2GB)
#     ├── loras/             (Lightx2v - 1.4GB)
#     ├── detection/         (ViTPose, YOLO - 1.5GB)
#     └── controlnet/        (Uni3C - 1.9GB)

# --- 9. Copy Handler Scripts ---
COPY src/start.sh /root/start.sh
COPY src/rp_handler.py /root/rp_handler.py
COPY src/ComfyUI_API_Wrapper.py /root/ComfyUI_API_Wrapper.py

RUN chmod +x /root/start.sh

# --- 10. Start Container ---
CMD ["/root/start.sh"]
