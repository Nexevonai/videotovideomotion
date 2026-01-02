# Vibe Voice API Integration Guide

Complete guide for integrating the Vibe Voice TTS workflow with your frontend application.

---

## Table of Contents
1. [API Endpoint](#api-endpoint)
2. [Request Format](#request-format)
3. [Response Format](#response-format)
4. [Workflow Parameters](#workflow-parameters)
5. [Frontend Integration Examples](#frontend-integration-examples)
6. [Error Handling](#error-handling)
7. [Best Practices](#best-practices)

---

## API Endpoint

### RunPod Serverless Endpoint
```
POST https://api.runpod.ai/v2/{ENDPOINT_ID}/run
```

### Headers
```json
{
  "Content-Type": "application/json",
  "Authorization": "Bearer YOUR_RUNPOD_API_KEY"
}
```

---

## Request Format

### Complete Request Structure

```json
{
  "input": {
    "audio_url": "https://example.com/voice-sample.mp3",
    "workflow": {
      "2": {
        "inputs": {
          "audio": "placeholder_audio.mp3"
        },
        "class_type": "LoadAudio",
        "_meta": {
          "title": "LoadAudio"
        }
      },
      "7": {
        "inputs": {
          "text": "Your text to be spoken here",
          "model": "VibeVoice-Large",
          "language": "auto",
          "quantize_llm": "full precision",
          "attention_type": "auto",
          "use_sampling": true,
          "seed": 45,
          "diffusion_steps": 42,
          "cfg_scale": 1.3,
          "free_memory_after_generate": false,
          "top_p": 0.95,
          "top_k": 0.95,
          "repetition_penalty": 1.0,
          "speaker1_voice": ["2", 0]
        },
        "class_type": "VibeVoiceMultipleSpeakersNode",
        "_meta": {
          "title": "Vibe Voice Multiple Speakers"
        }
      },
      "11": {
        "inputs": {
          "filename_prefix": "audio/ComfyUI",
          "quality": "320k",
          "audio": ["7", 0]
        },
        "class_type": "SaveAudioMP3",
        "_meta": {
          "title": "Save Audio (MP3)"
        }
      }
    }
  }
}
```

---

## Response Format

### Success Response
```json
{
  "delayTime": 120,
  "executionTime": 45000,
  "id": "request-uuid-here",
  "output": {
    "audio": [
      "https://pub-xxx.r2.dev/uuid_filename.mp3"
    ]
  },
  "status": "COMPLETED",
  "workerId": "worker-id"
}
```

### Error Response
```json
{
  "delayTime": 1000,
  "error": "Error message description",
  "executionTime": 500,
  "id": "request-uuid-here",
  "status": "FAILED",
  "workerId": "worker-id"
}
```

---

## Workflow Parameters

### Required Parameters (Always Include)

#### 1. **audio_url** (Top Level)
- **Type**: String (URL)
- **Purpose**: Public URL of the voice sample to clone
- **Format**: MP3, WAV, or other audio formats
- **Example**: `"https://example.com/trump-voice.mp3"`

#### 2. **text** (Node 7)
- **Type**: String
- **Purpose**: The text to be spoken
- **Max Length**: ~2000 characters (depends on model)
- **Example**: `"Hello! This is a test."`

#### 3. **model** (Node 7)
- **Type**: String
- **Options**: `"VibeVoice-Large"` (only option in this setup)
- **Purpose**: Specifies which TTS model to use

### Adjustable Parameters (Fine-tuning)

#### Voice Quality

**language**
- **Type**: String
- **Options**: `"auto"`, `"en"`, `"zh"`, etc.
- **Default**: `"auto"`
- **Purpose**: Language of the text (auto-detect works well)

**quantize_llm**
- **Type**: String
- **Options**: `"full precision"`, `"4bit"`, `"8bit"`
- **Default**: `"full precision"`
- **Purpose**: Model precision (lower = faster but lower quality)

**attention_type**
- **Type**: String
- **Options**: `"auto"`, `"eager"`, `"sdpa"`, `"flash_attention_2"`
- **Default**: `"auto"`
- **Purpose**: Attention mechanism (auto is recommended)

#### Generation Settings

**seed**
- **Type**: Integer
- **Range**: 0 to 999999
- **Default**: `45`
- **Purpose**: Random seed for reproducible results (same seed = same output)

**diffusion_steps**
- **Type**: Integer
- **Range**: 20 to 100
- **Default**: `42`
- **Purpose**: Quality vs speed tradeoff (higher = better quality, slower)

**cfg_scale**
- **Type**: Float
- **Range**: 1.0 to 2.0
- **Default**: `1.3`
- **Purpose**: How closely to follow the voice sample (higher = more similar)

#### Sampling Parameters

**use_sampling**
- **Type**: Boolean
- **Default**: `true`
- **Purpose**: Enable probabilistic sampling (recommended)

**top_p**
- **Type**: Float
- **Range**: 0.0 to 1.0
- **Default**: `0.95`
- **Purpose**: Nucleus sampling threshold (diversity control)

**top_k**
- **Type**: Float
- **Range**: 0.0 to 1.0
- **Default**: `0.95`
- **Purpose**: Top-k sampling threshold

**repetition_penalty**
- **Type**: Float
- **Range**: 1.0 to 2.0
- **Default**: `1.0`
- **Purpose**: Penalty for repeating tokens (1.0 = no penalty)

#### System Settings

**free_memory_after_generate**
- **Type**: Boolean
- **Default**: `false`
- **Purpose**: Free GPU memory after generation (set true if memory constrained)

### Audio Output Settings (Node 11)

**quality**
- **Type**: String
- **Options**: `"320k"`, `"256k"`, `"192k"`, `"128k"`
- **Default**: `"320k"`
- **Purpose**: MP3 bitrate (higher = better quality, larger file)

**filename_prefix**
- **Type**: String
- **Default**: `"audio/ComfyUI"`
- **Purpose**: Output filename prefix (usually keep as is)

---

## Frontend Integration Examples

### React/Next.js Example

```typescript
import { useState } from 'react';

interface VoiceCloneResponse {
  audio: string[];
}

export function VoiceCloner() {
  const [audioUrl, setAudioUrl] = useState('');
  const [text, setText] = useState('');
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<string | null>(null);

  const generateVoice = async () => {
    setLoading(true);

    try {
      const response = await fetch('https://api.runpod.ai/v2/YOUR_ENDPOINT_ID/run', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${process.env.NEXT_PUBLIC_RUNPOD_API_KEY}`
        },
        body: JSON.stringify({
          input: {
            audio_url: audioUrl,
            workflow: {
              "2": {
                "inputs": { "audio": "placeholder_audio.mp3" },
                "class_type": "LoadAudio",
                "_meta": { "title": "LoadAudio" }
              },
              "7": {
                "inputs": {
                  "text": text,
                  "model": "VibeVoice-Large",
                  "language": "auto",
                  "quantize_llm": "full precision",
                  "attention_type": "auto",
                  "use_sampling": true,
                  "seed": Math.floor(Math.random() * 999999), // Random seed
                  "diffusion_steps": 42,
                  "cfg_scale": 1.3,
                  "free_memory_after_generate": false,
                  "top_p": 0.95,
                  "top_k": 0.95,
                  "repetition_penalty": 1.0,
                  "speaker1_voice": ["2", 0]
                },
                "class_type": "VibeVoiceMultipleSpeakersNode",
                "_meta": { "title": "Vibe Voice Multiple Speakers" }
              },
              "11": {
                "inputs": {
                  "filename_prefix": "audio/ComfyUI",
                  "quality": "320k",
                  "audio": ["7", 0]
                },
                "class_type": "SaveAudioMP3",
                "_meta": { "title": "Save Audio (MP3)" }
              }
            }
          }
        })
      });

      const data = await response.json();

      if (data.status === 'COMPLETED' && data.output?.audio?.[0]) {
        setResult(data.output.audio[0]);
      } else {
        throw new Error(data.error || 'Generation failed');
      }
    } catch (error) {
      console.error('Error:', error);
      alert('Failed to generate voice');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <input
        type="url"
        placeholder="Voice sample URL"
        value={audioUrl}
        onChange={(e) => setAudioUrl(e.target.value)}
      />

      <textarea
        placeholder="Text to speak..."
        value={text}
        onChange={(e) => setText(e.target.value)}
        rows={5}
      />

      <button onClick={generateVoice} disabled={loading}>
        {loading ? 'Generating...' : 'Generate Voice'}
      </button>

      {result && (
        <audio controls src={result}>
          Your browser does not support audio.
        </audio>
      )}
    </div>
  );
}
```

### Python Example

```python
import requests
import json
import os

def generate_voice_clone(audio_url: str, text: str) -> str:
    """
    Generate cloned voice audio from text.

    Args:
        audio_url: Public URL to voice sample audio file
        text: Text to be spoken

    Returns:
        URL to generated MP3 file
    """
    endpoint = f"https://api.runpod.ai/v2/{os.getenv('RUNPOD_ENDPOINT_ID')}/run"

    payload = {
        "input": {
            "audio_url": audio_url,
            "workflow": {
                "2": {
                    "inputs": {"audio": "placeholder_audio.mp3"},
                    "class_type": "LoadAudio",
                    "_meta": {"title": "LoadAudio"}
                },
                "7": {
                    "inputs": {
                        "text": text,
                        "model": "VibeVoice-Large",
                        "language": "auto",
                        "quantize_llm": "full precision",
                        "attention_type": "auto",
                        "use_sampling": True,
                        "seed": 45,
                        "diffusion_steps": 42,
                        "cfg_scale": 1.3,
                        "free_memory_after_generate": False,
                        "top_p": 0.95,
                        "top_k": 0.95,
                        "repetition_penalty": 1.0,
                        "speaker1_voice": ["2", 0]
                    },
                    "class_type": "VibeVoiceMultipleSpeakersNode",
                    "_meta": {"title": "Vibe Voice Multiple Speakers"}
                },
                "11": {
                    "inputs": {
                        "filename_prefix": "audio/ComfyUI",
                        "quality": "320k",
                        "audio": ["7", 0]
                    },
                    "class_type": "SaveAudioMP3",
                    "_meta": {"title": "Save Audio (MP3)"}
                }
            }
        }
    }

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {os.getenv('RUNPOD_API_KEY')}"
    }

    response = requests.post(endpoint, json=payload, headers=headers)
    response.raise_for_status()

    data = response.json()

    if data.get('status') == 'COMPLETED' and data.get('output', {}).get('audio'):
        return data['output']['audio'][0]
    else:
        raise Exception(f"Generation failed: {data.get('error', 'Unknown error')}")

# Usage
if __name__ == "__main__":
    audio_url = "https://example.com/voice-sample.mp3"
    text = "Hello! This is a test of voice cloning."

    try:
        result_url = generate_voice_clone(audio_url, text)
        print(f"Generated audio: {result_url}")
    except Exception as e:
        print(f"Error: {e}")
```

### cURL Example

```bash
curl -X POST https://api.runpod.ai/v2/YOUR_ENDPOINT_ID/run \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_RUNPOD_API_KEY" \
  -d '{
    "input": {
      "audio_url": "https://example.com/voice.mp3",
      "workflow": {
        "2": {
          "inputs": {"audio": "placeholder_audio.mp3"},
          "class_type": "LoadAudio",
          "_meta": {"title": "LoadAudio"}
        },
        "7": {
          "inputs": {
            "text": "Hello world!",
            "model": "VibeVoice-Large",
            "language": "auto",
            "quantize_llm": "full precision",
            "attention_type": "auto",
            "use_sampling": true,
            "seed": 45,
            "diffusion_steps": 42,
            "cfg_scale": 1.3,
            "free_memory_after_generate": false,
            "top_p": 0.95,
            "top_k": 0.95,
            "repetition_penalty": 1.0,
            "speaker1_voice": ["2", 0]
          },
          "class_type": "VibeVoiceMultipleSpeakersNode",
          "_meta": {"title": "Vibe Voice Multiple Speakers"}
        },
        "11": {
          "inputs": {
            "filename_prefix": "audio/ComfyUI",
            "quality": "320k",
            "audio": ["7", 0]
          },
          "class_type": "SaveAudioMP3",
          "_meta": {"title": "Save Audio (MP3)"}
        }
      }
    }
  }'
```

---

## Error Handling

### Common Errors

**1. "无法从指定的URL下载音频"**
- **Meaning**: Cannot download audio from URL
- **Solution**: Ensure audio_url is publicly accessible, use raw GitHub URLs

**2. "Required input is missing: [parameter]"**
- **Meaning**: Missing workflow parameter
- **Solution**: Check all required parameters are present in node 7

**3. "执行超时或工作流未生成任何音频输出"**
- **Meaning**: Workflow timeout or no output
- **Solution**: Check worker logs for specific errors

**4. "Model loading failed"**
- **Meaning**: VibeVoice model not loaded
- **Solution**: Rebuild Docker image with correct dependencies

### Error Handling Template

```typescript
async function handleVoiceGeneration() {
  try {
    const response = await generateVoice(audioUrl, text);
    return response;
  } catch (error) {
    if (error.message.includes('download')) {
      alert('Audio file not accessible. Please use a public URL.');
    } else if (error.message.includes('timeout')) {
      alert('Generation took too long. Please try again.');
    } else if (error.message.includes('missing')) {
      alert('Invalid request format. Please check parameters.');
    } else {
      alert('Generation failed. Please try again.');
    }
  }
}
```

---

## Best Practices

### 1. **Audio Sample Quality**
- Use clear, noise-free voice samples
- 3-10 seconds of speech is ideal
- Single speaker only
- WAV or high-quality MP3 (320kbps)

### 2. **Text Input**
- Keep under 500 characters for best results
- Use proper punctuation for natural pauses
- Avoid special characters that don't speak naturally

### 3. **Parameter Tuning**

**For Faster Generation:**
```json
{
  "diffusion_steps": 30,
  "quantize_llm": "8bit"
}
```

**For Best Quality:**
```json
{
  "diffusion_steps": 50,
  "quantize_llm": "full precision",
  "cfg_scale": 1.5
}
```

**For More Voice Similarity:**
```json
{
  "cfg_scale": 1.5,
  "top_p": 0.9,
  "top_k": 0.9
}
```

### 4. **Cost Optimization**
- Set `free_memory_after_generate: true` to reduce idle costs
- Use lower quality MP3 (192k) if file size matters
- Cache frequently used voice samples

### 5. **Security**
- Never expose RunPod API key in frontend code
- Use backend proxy for API calls
- Validate and sanitize user text input
- Rate limit requests to prevent abuse

---

## Environment Variables

Create a `.env` file:

```bash
RUNPOD_API_KEY=your_api_key_here
RUNPOD_ENDPOINT_ID=ob2pgiqcxhcpg0
R2_PUBLIC_URL=https://pub-xxx.r2.dev
```

---

## Rate Limits & Costs

### Execution Time
- **First generation**: 10-20 seconds (cold start)
- **Subsequent**: 15-20 seconds per request
- **Text length impact**: +2-3 seconds per 100 characters

### Cost Estimation (RTX 4090)
- **Per minute**: ~$0.00024
- **Per request**: ~$0.008-0.012
- **Idle time**: Billed at same rate (set idle timeout low!)

### Optimization Tips
- Set Max Workers to 1-3 for testing
- Set Idle Timeout to 5 seconds
- Use Active Workers = 0 (scale to zero when idle)

---

## Testing Checklist

- [ ] Audio URL is publicly accessible
- [ ] Audio URL uses raw format (not HTML page)
- [ ] Text is under 500 characters
- [ ] All required parameters present
- [ ] API key has correct permissions
- [ ] Endpoint ID is correct
- [ ] Error handling implemented
- [ ] Loading states shown to user
- [ ] Audio player tested in browser

---

## Support & Resources

- **GitHub**: [Nexevonai/vibeboiceser](https://github.com/Nexevonai/vibeboiceser)
- **VibeVoice Docs**: [GitHub](https://github.com/Enemyx-net/VibeVoice-ComfyUI)
- **RunPod Docs**: [docs.runpod.io](https://docs.runpod.io)

---

**Last Updated**: November 2025
