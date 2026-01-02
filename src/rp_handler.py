import os
import json
import uuid
import runpod
import base64
import requests
import boto3
from botocore.client import Config
from ComfyUI_API_Wrapper import ComfyUI_API_Wrapper

# --- Global Constants ---
COMFYUI_URL = "http://127.0.0.1:8188"
client_id = str(uuid.uuid4())
output_path = "/root/comfy/ComfyUI/output"
input_path = "/root/comfy/ComfyUI/input"
api = ComfyUI_API_Wrapper(COMFYUI_URL, client_id, output_path)

# --- Helper Functions ---

def download_file(url, save_path, timeout=60):
    """Download a file from URL to local path."""
    try:
        response = requests.get(url, stream=True, timeout=timeout)
        response.raise_for_status()
        with open(save_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        return True
    except requests.exceptions.RequestException as e:
        print(f"Error downloading file: {e}")
        return False

def download_video(url, filename=None):
    """Download video file and return the local filename."""
    if not os.path.exists(input_path):
        os.makedirs(input_path)

    if filename is None:
        # Determine extension from URL or default to mp4
        ext = os.path.splitext(url.split('?')[0])[-1] or '.mp4'
        filename = f"video_{uuid.uuid4()}{ext}"

    save_path = os.path.join(input_path, filename)
    if download_file(url, save_path, timeout=120):
        return filename
    return None

def download_image(url, filename=None):
    """Download image file and return the local filename."""
    if not os.path.exists(input_path):
        os.makedirs(input_path)

    if filename is None:
        # Determine extension from URL or default to png
        ext = os.path.splitext(url.split('?')[0])[-1] or '.png'
        filename = f"image_{uuid.uuid4()}{ext}"

    save_path = os.path.join(input_path, filename)
    if download_file(url, save_path, timeout=30):
        return filename
    return None

def find_nodes_by_class(workflow, class_type):
    """Find all node IDs matching a class type."""
    nodes = []
    for node_id, node_data in workflow.items():
        if node_data.get("class_type") == class_type:
            nodes.append(node_id)
    return nodes

def get_content_type(filename):
    """Get content type based on file extension."""
    ext = os.path.splitext(filename)[-1].lower()
    content_types = {
        '.mp4': 'video/mp4',
        '.webm': 'video/webm',
        '.mov': 'video/quicktime',
        '.avi': 'video/x-msvideo',
        '.gif': 'image/gif',
        '.png': 'image/png',
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
    }
    return content_types.get(ext, 'application/octet-stream')

# --- RunPod Handler ---
def handler(job):
    job_input = job.get('input', {})

    # 1. Get workflow from input
    workflow = job_input.get('workflow')
    if not workflow or not isinstance(workflow, dict):
        return {"error": "Input error: 'workflow' key is required and must be a valid JSON object."}

    # 2. Handle video_url input (driving video for motion transfer)
    if 'video_url' in job_input:
        video_url = job_input['video_url']
        video_filename = download_video(video_url)

        if not video_filename:
            return {"error": f"Failed to download video from: {video_url}"}

        # Find VHS_LoadVideo nodes and inject the video filename
        load_video_nodes = find_nodes_by_class(workflow, "VHS_LoadVideo")
        if load_video_nodes:
            for node_id in load_video_nodes:
                workflow[node_id]["inputs"]["video"] = video_filename
                print(f"Injected video '{video_filename}' into VHS_LoadVideo node {node_id}")
        else:
            print("Warning: video_url provided but no VHS_LoadVideo node found in workflow")

    # 3. Handle image_url input (reference character image)
    if 'image_url' in job_input:
        image_url = job_input['image_url']
        image_filename = download_image(image_url)

        if not image_filename:
            return {"error": f"Failed to download image from: {image_url}"}

        # Find LoadImage nodes and inject the image filename
        load_image_nodes = find_nodes_by_class(workflow, "LoadImage")
        if load_image_nodes:
            # Inject into the first LoadImage node (or all if needed)
            for node_id in load_image_nodes:
                workflow[node_id]["inputs"]["image"] = image_filename
                print(f"Injected image '{image_filename}' into LoadImage node {node_id}")
        else:
            print("Warning: image_url provided but no LoadImage node found in workflow")

    # 4. Handle additional image URLs (for multi-character workflows)
    # Format: image_url_1, image_url_2, etc. or images: [{url, node_id}, ...]
    if 'images' in job_input and isinstance(job_input['images'], list):
        for img_config in job_input['images']:
            if isinstance(img_config, dict):
                img_url = img_config.get('url')
                target_node = img_config.get('node_id')
                if img_url and target_node:
                    img_filename = download_image(img_url)
                    if img_filename and target_node in workflow:
                        workflow[target_node]["inputs"]["image"] = img_filename
                        print(f"Injected image '{img_filename}' into node {target_node}")

    # 5. Find output node (VHS_VideoCombine for video output)
    output_node_id = None
    output_type = "video"

    # Priority: VHS_VideoCombine > SaveImage > other output nodes
    video_combine_nodes = find_nodes_by_class(workflow, "VHS_VideoCombine")
    if video_combine_nodes:
        output_node_id = video_combine_nodes[0]
        output_type = "video"
    else:
        # Fallback to SaveImage if no video output
        save_image_nodes = find_nodes_by_class(workflow, "SaveImage")
        if save_image_nodes:
            output_node_id = save_image_nodes[0]
            output_type = "images"

    if not output_node_id:
        return {"error": "Workflow must contain a 'VHS_VideoCombine' or 'SaveImage' node for output."}

    try:
        # 6. Execute workflow
        print(f"Executing workflow with output node: {output_node_id} (type: {output_type})")
        output_data = api.queue_prompt_and_get_images(workflow, output_node_id)

        if not output_data:
            return {"error": "Execution timeout or workflow produced no output."}

        # 7. Upload output files to Cloudflare R2
        s3_client = boto3.client(
            's3',
            endpoint_url=os.environ.get('R2_ENDPOINT_URL'),
            aws_access_key_id=os.environ.get('R2_ACCESS_KEY_ID'),
            aws_secret_access_key=os.environ.get('R2_SECRET_ACCESS_KEY'),
            config=Config(signature_version='s3v4')
        )

        bucket_name = os.environ.get('R2_BUCKET_NAME')
        public_url_base = os.environ.get('R2_PUBLIC_URL')

        output_urls = []
        for file_info in output_data:
            filename = file_info.get("filename")
            if filename:
                # Get file bytes from ComfyUI
                file_bytes = api.get_image(
                    filename,
                    file_info.get("subfolder", ""),
                    file_info.get("type", "output")
                )

                # Generate unique filename for R2
                unique_filename = f"{uuid.uuid4()}_{filename}"

                # Determine content type
                content_type = get_content_type(filename)

                # Upload to R2
                s3_client.put_object(
                    Bucket=bucket_name,
                    Key=unique_filename,
                    Body=file_bytes,
                    ContentType=content_type
                )

                # Build public URL
                file_url = f"{public_url_base}/{unique_filename}"
                output_urls.append(file_url)
                print(f"Uploaded: {file_url}")

        # 8. Return result based on output type
        return {output_type: output_urls}

    except Exception as e:
        import traceback
        error_msg = f"Error during processing: {str(e)}\n{traceback.format_exc()}"
        print(error_msg)
        return {"error": error_msg}

# --- Start RunPod Worker ---
if __name__ == "__main__":
    print("SCAIL Video Motion Transfer Worker starting...")
    runpod.serverless.start({"handler": handler})
