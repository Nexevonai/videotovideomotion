#!/usr/bin/env bash
set -e

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

echo "SCAIL Worker: Starting ComfyUI in the background..."

# Start ComfyUI server in the background
/venv/bin/python /root/comfy/ComfyUI/main.py --disable-auto-launch --listen 0.0.0.0 --port 8188 &

# Wait for ComfyUI to be ready
echo "Waiting for ComfyUI to be ready..."
max_attempts=120
attempt=0
while ! curl --silent --fail --head http://127.0.0.1:8188/history > /dev/null; do
    echo -n "."
    sleep 2
    attempt=$((attempt + 1))
    if [ $attempt -ge $max_attempts ]; then
        echo ""
        echo "ERROR: ComfyUI failed to start after ${max_attempts} attempts"
        exit 1
    fi
done
echo ""
echo "ComfyUI is ready and listening on port 8188"

echo "SCAIL Worker: Starting RunPod Handler..."
# Start the RunPod handler
/venv/bin/python -u /root/rp_handler.py
