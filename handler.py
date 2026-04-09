"""
RunPod Serverless Handler for ComfyUI
Accepts ComfyUI workflow JSON, executes it, returns base64 images.
"""

import runpod
import subprocess
import requests
import base64
import json
import os
import time
import glob
import uuid
import logging
from pathlib import Path

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("comfyui-handler")

# ============================================================
# Configuration
# ============================================================

COMFYUI_DIR = os.environ.get("COMFYUI_DIR", "/workspace/ComfyUI")
COMFYUI_HOST = "127.0.0.1"
COMFYUI_PORT = 8188
COMFYUI_URL = f"http://{COMFYUI_HOST}:{COMFYUI_PORT}"

# RunPod S3 configuration for LoRA downloads
S3_ENDPOINT = os.environ.get("S3_ENDPOINT", "https://s3api-eur-is-1.runpod.io")
S3_BUCKET = os.environ.get("S3_BUCKET", "ff8on0esxh")
S3_REGION = os.environ.get("S3_REGION", "eur-is-1")
S3_ACCESS_KEY = os.environ.get("RUNPOD_S3_ACCESS_KEY_ID", "")
S3_SECRET_KEY = os.environ.get("RUNPOD_S3_SECRET_ACCESS_KEY", "")

# Paths
MODELS_DIR = os.path.join(COMFYUI_DIR, "models")
LORAS_DIR = os.path.join(MODELS_DIR, "loras")
INPUT_DIR = os.path.join(COMFYUI_DIR, "input")
OUTPUT_DIR = os.path.join(COMFYUI_DIR, "output")

# ComfyUI process handle
comfyui_process = None


# ============================================================
# ComfyUI Server Management
# ============================================================

def start_comfyui():
    """Start ComfyUI server as a subprocess."""
    global comfyui_process

    if comfyui_process is not None and comfyui_process.poll() is None:
        logger.info("ComfyUI is already running")
        return

    logger.info("Starting ComfyUI server...")
    log_file = open("/tmp/comfyui.log", "w")
    comfyui_process = subprocess.Popen(
        [
            "python", "main.py",
            "--listen", COMFYUI_HOST,
            "--port", str(COMFYUI_PORT),
            "--disable-auto-launch",
            "--disable-metadata",
        ],
        cwd=COMFYUI_DIR,
        stdout=log_file,
        stderr=subprocess.STDOUT,
    )
    logger.info(f"ComfyUI process started with PID {comfyui_process.pid}")


def wait_for_comfyui(timeout=180):
    """Wait for ComfyUI to be ready by polling its API."""
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            resp = requests.get(f"{COMFYUI_URL}/system_stats", timeout=5)
            if resp.status_code == 200:
                logger.info("ComfyUI is ready")
                return True
        except requests.exceptions.ConnectionError:
            pass
        except Exception as e:
            logger.warning(f"Waiting for ComfyUI: {e}")

        # Check if process crashed
        if comfyui_process and comfyui_process.poll() is not None:
            try:
                with open("/tmp/comfyui.log", "r") as f:
                    log_tail = f.read()[-2000:]
            except Exception:
                log_tail = "Log not available"
            raise RuntimeError(f"ComfyUI process exited with code {comfyui_process.returncode}. Output: {log_tail}")

        time.sleep(2)

    raise TimeoutError(f"ComfyUI did not start within {timeout} seconds")


# ============================================================
# Image Upload Handling
# ============================================================

def save_uploaded_images(job_input):
    """
    Decode base64 images from job input and save to ComfyUI input directory.
    Handles: imageBase64, sourceImageBase64, targetImageBase64
    """
    os.makedirs(INPUT_DIR, exist_ok=True)
    saved_files = {}

    image_fields = [
        ("imageBase64", "uploadedImageFilename", "uploaded_image.png"),
        ("sourceImageBase64", "uploadedSourceImageFilename", "uploaded_source.png"),
        ("targetImageBase64", "uploadedTargetImageFilename", "uploaded_target.png"),
    ]

    for base64_key, filename_key, default_name in image_fields:
        base64_data = job_input.get(base64_key)
        if not base64_data:
            continue

        filename = job_input.get(filename_key, default_name)
        # Sanitize filename to prevent path traversal
        filename = os.path.basename(filename)

        # Strip data URL prefix if present
        if "," in base64_data:
            base64_data = base64_data.split(",", 1)[1]

        try:
            image_bytes = base64.b64decode(base64_data)
            filepath = os.path.join(INPUT_DIR, filename)
            with open(filepath, "wb") as f:
                f.write(image_bytes)
            saved_files[filename_key] = filename
            logger.info(f"Saved uploaded image: {filename} ({len(image_bytes)} bytes)")
        except Exception as e:
            logger.error(f"Failed to save {base64_key}: {e}")

    return saved_files


# ============================================================
# LoRA Management
# ============================================================

def get_s3_client():
    """Create boto3 S3 client for RunPod S3."""
    try:
        import boto3
        return boto3.client(
            "s3",
            endpoint_url=S3_ENDPOINT,
            aws_access_key_id=S3_ACCESS_KEY,
            aws_secret_access_key=S3_SECRET_KEY,
            region_name=S3_REGION,
        )
    except Exception as e:
        logger.error(f"Failed to create S3 client: {e}")
        return None


def download_lora_from_s3(lora_filename):
    """Download a LoRA file from RunPod S3 if not already cached locally."""
    local_path = os.path.join(LORAS_DIR, lora_filename)

    if os.path.exists(local_path):
        logger.info(f"LoRA already cached: {lora_filename}")
        return True

    s3_key = f"ComfyUI/models/loras/{lora_filename}"
    logger.info(f"Downloading LoRA from S3: {s3_key}")

    s3 = get_s3_client()
    if not s3:
        return False

    try:
        os.makedirs(LORAS_DIR, exist_ok=True)
        s3.download_file(S3_BUCKET, s3_key, local_path)
        logger.info(f"Downloaded LoRA: {lora_filename} ({os.path.getsize(local_path)} bytes)")
        return True
    except Exception as e:
        logger.error(f"Failed to download LoRA {lora_filename}: {e}")
        # Clean up partial download
        if os.path.exists(local_path):
            os.remove(local_path)
        return False


def ensure_loras_available(workflow):
    """
    Scan workflow for LoRA references and download any missing ones from S3.
    Checks both 'Lora Loader Stack (rgthree)' and 'Power Lora Loader (rgthree)' nodes.
    """
    if not workflow:
        return

    for node_id, node in workflow.items():
        if not isinstance(node, dict):
            continue

        class_type = node.get("class_type", "")
        inputs = node.get("inputs", {})

        # Check Lora Loader Stack (rgthree) - has lora_01 through lora_04
        if class_type == "Lora Loader Stack (rgthree)":
            for key in ["lora_01", "lora_02", "lora_03", "lora_04"]:
                lora_name = inputs.get(key)
                if lora_name and lora_name != "None" and lora_name.strip():
                    if not download_lora_from_s3(lora_name):
                        raise RuntimeError(f"Failed to download required LoRA: {lora_name}")

        # Check Power Lora Loader (rgthree) - has lora_1 through lora_3
        elif class_type == "Power Lora Loader (rgthree)":
            for key in ["lora_1", "lora_2", "lora_3"]:
                lora_value = inputs.get(key)
                if isinstance(lora_value, dict):
                    lora_name = lora_value.get("lora")
                    if lora_name and lora_name != "None" and lora_name.strip():
                        if not download_lora_from_s3(lora_name):
                            raise RuntimeError(f"Failed to download required LoRA: {lora_name}")
                elif isinstance(lora_value, str) and lora_value != "None" and lora_value.strip():
                    if not download_lora_from_s3(lora_value):
                        raise RuntimeError(f"Failed to download required LoRA: {lora_value}")


# ============================================================
# Workflow Execution
# ============================================================

def queue_workflow(workflow):
    """Submit workflow to ComfyUI via /prompt endpoint."""
    payload = {"prompt": workflow}

    resp = requests.post(
        f"{COMFYUI_URL}/prompt",
        json=payload,
        timeout=30,
    )

    if resp.status_code != 200:
        error_text = resp.text[:1000]
        raise RuntimeError(f"ComfyUI /prompt returned {resp.status_code}: {error_text}")

    data = resp.json()
    prompt_id = data.get("prompt_id")
    if not prompt_id:
        raise RuntimeError(f"No prompt_id in ComfyUI response: {data}")

    logger.info(f"Workflow queued with prompt_id: {prompt_id}")

    # Check for node errors
    node_errors = data.get("node_errors", {})
    if node_errors:
        logger.warning(f"Node errors in workflow: {json.dumps(node_errors)[:500]}")

    return prompt_id


def poll_for_completion(prompt_id, timeout=600):
    """
    Poll ComfyUI /history endpoint until the workflow completes.
    Returns the output data for the prompt.
    """
    start_time = time.time()
    poll_interval = 1  # Start with 1s, increase over time

    while time.time() - start_time < timeout:
        try:
            resp = requests.get(
                f"{COMFYUI_URL}/history/{prompt_id}",
                timeout=10,
            )

            if resp.status_code == 200:
                history = resp.json()
                if prompt_id in history:
                    prompt_data = history[prompt_id]

                    # Check for errors
                    status_data = prompt_data.get("status", {})
                    if status_data.get("status_str") == "error":
                        messages = status_data.get("messages", [])
                        error_msg = json.dumps(messages)[:1000] if messages else "Unknown error"
                        raise RuntimeError(f"ComfyUI workflow error: {error_msg}")

                    # Check if completed (has outputs)
                    outputs = prompt_data.get("outputs", {})
                    if outputs:
                        logger.info(f"Workflow completed. Output nodes: {list(outputs.keys())}")
                        return outputs

        except requests.exceptions.RequestException as e:
            logger.warning(f"Polling error: {e}")

        time.sleep(poll_interval)
        # Gradually increase poll interval (max 3s)
        poll_interval = min(poll_interval + 0.5, 3)

    raise TimeoutError(f"Workflow did not complete within {timeout} seconds")


def collect_output_images(outputs):
    """
    Read generated images from ComfyUI output and return as base64 data URLs.
    Returns list of base64-encoded image strings with data: prefix.
    """
    images = []

    # Find SaveImage nodes in outputs (skip PreviewImage)
    save_nodes = {}
    preview_nodes = {}

    for node_id, output in outputs.items():
        if "images" in output:
            for img_info in output["images"]:
                img_type = img_info.get("type", "output")
                if img_type == "temp":
                    preview_nodes[node_id] = output
                else:
                    save_nodes[node_id] = output

    # Prefer SaveImage nodes, fall back to PreviewImage
    target_nodes = save_nodes if save_nodes else preview_nodes

    for node_id, output in target_nodes.items():
        for img_info in output.get("images", []):
            filename = img_info.get("filename")
            subfolder = img_info.get("subfolder", "")
            img_type = img_info.get("type", "output")

            if not filename:
                continue

            # Build path to the image file
            if img_type == "temp":
                img_path = os.path.join(COMFYUI_DIR, "temp", subfolder, filename)
            else:
                img_path = os.path.join(OUTPUT_DIR, subfolder, filename)

            if not os.path.exists(img_path):
                logger.warning(f"Output image not found: {img_path}")
                continue

            try:
                with open(img_path, "rb") as f:
                    img_data = f.read()

                # Determine MIME type
                mime = "image/png"
                if filename.lower().endswith(".jpg") or filename.lower().endswith(".jpeg"):
                    mime = "image/jpeg"
                elif filename.lower().endswith(".webp"):
                    mime = "image/webp"

                b64 = base64.b64encode(img_data).decode("utf-8")
                images.append(f"data:{mime};base64,{b64}")
                logger.info(f"Collected image: {filename} ({len(img_data)} bytes)")

            except Exception as e:
                logger.error(f"Failed to read output image {filename}: {e}")

    return images


def cleanup_output_dir():
    """Remove old output files to prevent disk space issues."""
    try:
        for f in glob.glob(os.path.join(OUTPUT_DIR, "**", "*"), recursive=True):
            if os.path.isfile(f):
                os.remove(f)
        for f in glob.glob(os.path.join(COMFYUI_DIR, "temp", "**", "*"), recursive=True):
            if os.path.isfile(f):
                os.remove(f)
    except Exception as e:
        logger.warning(f"Cleanup error: {e}")


# ============================================================
# Main Handler
# ============================================================

def handler(job):
    """
    Main RunPod serverless handler.

    Input format (matches existing frontend submitRunPodJob):
    {
        "input": {
            "workflow": { ... ComfyUI workflow JSON ... },
            "uploadedImageFilename": "filename.png",  // optional
            "imageBase64": "base64data",               // optional
            "sourceImageBase64": "base64data",         // optional
            "targetImageBase64": "base64data",         // optional
        }
    }

    Output format (matches frontend pollForRunPodResult expectations):
    {
        "images": ["data:image/png;base64,...", ...],
        "status": "success"
    }
    """
    job_input = job.get("input", {})

    # Validate workflow
    workflow = job_input.get("workflow")
    if not workflow:
        raise ValueError("No workflow provided in input")

    try:
        # 1. Clean up old output files
        cleanup_output_dir()

        # 2. Save any uploaded images to ComfyUI input directory
        saved_images = save_uploaded_images(job_input)
        if saved_images:
            logger.info(f"Saved {len(saved_images)} uploaded images")

        # 3. Download any LoRA models referenced in workflow
        ensure_loras_available(workflow)

        # 4. Submit workflow to ComfyUI
        prompt_id = queue_workflow(workflow)

        # 5. Wait for completion
        outputs = poll_for_completion(prompt_id, timeout=600)

        # 6. Collect output images as base64
        images = collect_output_images(outputs)

        if not images:
            raise RuntimeError("Workflow completed but no output images were found")

        logger.info(f"Returning {len(images)} images")

        # Return in format expected by frontend (status.output.images)
        return {
            "images": images,
            "status": "success",
        }

    except Exception as e:
        logger.error(f"Handler error: {e}", exc_info=True)
        # Re-raise so RunPod marks job as FAILED (not COMPLETED with error data)
        raise


# ============================================================
# Startup
# ============================================================

# Start ComfyUI during container initialization (before receiving jobs)
# This ensures models are loaded into VRAM and the first job is fast
logger.info("=== ComfyUI Serverless Handler Starting ===")
start_comfyui()
wait_for_comfyui(timeout=180)
logger.info("=== ComfyUI Ready - Starting RunPod Handler ===")

runpod.serverless.start({"handler": handler})
