# SCAIL Video Motion Transfer - RunPod Serverless Project

## Project Overview

This project runs a **SCAIL (Studio-Grade Character Animation via In-Context Learning) video motion transfer workflow** on RunPod serverless infrastructure. It takes a driving video and reference character image, then generates a video with the character animated using the motion from the driving video.

### Original Project
- **Base**: VibeVoice TTS (audio workflow)
- **Converted to**: SCAIL Video Motion Transfer
- **Date Modified**: 2025-01-02

---

## How It Works

### Architecture
```
User API Request → RunPod Handler → ComfyUI (with SCAIL) → R2 Storage → Video URL Response
```

### Workflow Pipeline
1. **VHS_LoadVideo**: Loads driving video with motion
2. **LoadImage**: Loads reference character image
3. **SCAIL Processing**: Transfers motion to character using 14B model
4. **VHS_VideoCombine**: Outputs MP4 video

### Input Format
```json
{
  "input": {
    "video_url": "https://example.com/driving-video.mp4",
    "image_url": "https://example.com/character.png",
    "workflow": { ... complete workflow JSON (API format) ... }
  }
}
```

### Output Format
```json
{
  "video": [
    "https://pub-xxx.r2.dev/uuid_filename.mp4"
  ]
}
```

---

## Technical Specifications

### Models Used
- **SCAIL 14B BF16**: ~28GB (from `Kijai/WanVideo_comfy`)
- **Text Encoder**: umt5xxl_fp16.safetensors
- **VAE**: Wan2_1_VAE_bf16.safetensors
- **CLIP Vision**: clip_vision_h.safetensors
- **LoRA**: lightx2v_wan2.1_lora_bf16.safetensors
- **Uni3C ControlNet**: Wan21_Uni3C_controlnet_fp16.safetensors
- **ONNX Detection**: ViTPose wholebody + Wan2.2-Animate det

### VRAM Required
- ~40-50GB (H100 80GB recommended)

### Custom Nodes
| Node | Repository |
|------|------------|
| ComfyUI-WanVideoWrapper | https://github.com/kijai/ComfyUI-WanVideoWrapper |
| ComfyUI-KJNodes | https://github.com/kijai/ComfyUI-KJNodes |
| ComfyUI-SCAIL-Pose | https://github.com/kijai/ComfyUI-SCAIL-Pose |
| ComfyUI-WanAnimatePreprocess | https://github.com/kijai/ComfyUI-WanAnimatePreprocess |
| ComfyUI-VideoHelperSuite | https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite |
| comfyui_controlnet_aux | https://github.com/Fannovel16/comfyui_controlnet_aux |

### Storage
- **Cloudflare R2**: Video file storage
- **Format**: MP4 (H.264)

---

## Environment Variables Required

```bash
R2_ENDPOINT_URL=https://ACCOUNT_ID.r2.cloudflarestorage.com
R2_ACCESS_KEY_ID=your_access_key
R2_SECRET_ACCESS_KEY=your_secret_key
R2_BUCKET_NAME=your_bucket_name
R2_PUBLIC_URL=https://pub-xxx.r2.dev
```

---

## Key Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Container setup, model downloads, custom nodes |
| `src/rp_handler.py` | RunPod serverless handler (video/image I/O) |
| `src/ComfyUI_API_Wrapper.py` | ComfyUI API client |
| `src/start.sh` | Container startup script |
| `input.json` | Example API request |
| `response.json` | Example API response |
| `SCAIL+Video+Multi-Character+Motion+Transfer+V1.json` | Original workflow (UI format) |

---

## Build & Deploy

### Local Build
```bash
docker build -t scail-runpod .
```

### Deploy to RunPod
1. Push image to Docker Hub/Registry
2. Create RunPod serverless endpoint
3. Set environment variables (R2 credentials)
4. Select H100 GPU tier
5. Test with sample request

---

## API Usage

### Basic Request
```bash
curl -X POST https://api.runpod.ai/v2/YOUR_ENDPOINT_ID/runsync \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "video_url": "https://example.com/driving-video.mp4",
      "image_url": "https://example.com/character.png",
      "workflow": { ... }
    }
  }'
```

### Multi-Character Request
```bash
{
  "input": {
    "video_url": "https://example.com/driving-video.mp4",
    "images": [
      {"url": "https://example.com/char1.png", "node_id": "10"},
      {"url": "https://example.com/char2.png", "node_id": "15"}
    ],
    "workflow": { ... }
  }
}
```

---

## Workflow Format

**Important**: The workflow must be in **API format**, not UI format.

To convert from UI to API format in ComfyUI:
1. Enable Dev Mode: Settings → Enable Dev mode options
2. Save workflow using "Save (API Format)" button
3. Use the exported JSON in API requests

API format has flat structure with `class_type` field:
```json
{
  "1": {
    "inputs": { ... },
    "class_type": "VHS_LoadVideo"
  }
}
```

UI format has nested structure with `type` field (won't work):
```json
{
  "nodes": [
    {"id": 1, "type": "VHS_LoadVideo", ...}
  ]
}
```

---

## Notes

- Video files saved to: `/root/comfy/ComfyUI/input/`
- Output directory: `/root/comfy/ComfyUI/output/`
- ComfyUI runs on: `http://127.0.0.1:8188`
- Docker image size: ~50-60GB (models baked in)

---

## References

- [SCAIL GitHub](https://github.com/zai-org/SCAIL)
- [ComfyUI-WanVideoWrapper](https://github.com/kijai/ComfyUI-WanVideoWrapper)
- [Kijai/WanVideo_comfy Models](https://huggingface.co/Kijai/WanVideo_comfy)
- [RunPod Serverless Docs](https://docs.runpod.io/tutorials/serverless/comfyui)
