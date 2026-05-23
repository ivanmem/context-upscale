"""
Local upscale server — FastAPI + Real-ESRGAN with lazy model loading
and automatic VRAM unloading after idle timeout.
"""

import asyncio
import io
import logging
import re
import time
import uuid
from contextlib import asynccontextmanager
from pathlib import Path

import numpy as np
import torch
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from PIL import Image

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
IDLE_TIMEOUT_SEC = 5 * 60
MODEL_SCALE = 4
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
WEIGHTS_DIR = Path(__file__).parent / "weights"
TILE_SIZE = 512
RESULT_TTL_SEC = 300

# ---------------------------------------------------------------------------
# Global state
# ---------------------------------------------------------------------------
_model = None
_last_used: float = 0.0
_unload_task: asyncio.Task | None = None
_lock = asyncio.Lock()
_results: dict[str, tuple[bytes, float]] = {}


def _convert_old_keys(state_dict):
    new_dict = {}
    for k, v in state_dict.items():
        nk = k
        if k == "model.0.weight":
            nk = "conv_first.weight"
        elif k == "model.0.bias":
            nk = "conv_first.bias"
        elif m := re.match(r"model\.1\.sub\.(\d+)\.RDB(\d+)\.conv(\d+)\.0\.(weight|bias)", k):
            nk = f"body.{m.group(1)}.rdb{m.group(2)}.conv{m.group(3)}.{m.group(4)}"
        elif k == "model.1.sub.23.weight":
            nk = "conv_body.weight"
        elif k == "model.1.sub.23.bias":
            nk = "conv_body.bias"
        elif k == "model.3.weight":
            nk = "conv_up1.weight"
        elif k == "model.3.bias":
            nk = "conv_up1.bias"
        elif k == "model.6.weight":
            nk = "conv_up2.weight"
        elif k == "model.6.bias":
            nk = "conv_up2.bias"
        elif k == "model.8.weight":
            nk = "conv_hr.weight"
        elif k == "model.8.bias":
            nk = "conv_hr.bias"
        elif k == "model.10.weight":
            nk = "conv_last.weight"
        elif k == "model.10.bias":
            nk = "conv_last.bias"
        new_dict[nk] = v
    return new_dict


def _load_model():
    global _model
    if _model is not None:
        return
    logger.info("Loading Real-ESRGAN model on %s ...", DEVICE)
    from basicsr.archs.rrdbnet_arch import RRDBNet
    model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=23, num_grow_ch=32, scale=MODEL_SCALE)
    weights_path = WEIGHTS_DIR / "4x-UltraSharp.pth"
    if not weights_path.exists():
        raise FileNotFoundError(f"Weights not found at {weights_path}")
    loadnet = torch.load(str(weights_path), map_location=torch.device("cpu"), weights_only=False)
    sd = loadnet.get("params") or loadnet.get("params_ema") or loadnet
    if next(iter(sd)).startswith("model."):
        logger.info("Detected old BasicSR key format, converting...")
        sd = _convert_old_keys(sd)
    model.load_state_dict(sd, strict=True)
    model.eval()
    model = model.to(DEVICE)
    _model = model
    logger.info("Model loaded successfully.")


def _unload_model():
    global _model
    if _model is None:
        return
    logger.info("Unloading model from %s ...", DEVICE)
    del _model
    _model = None
    if DEVICE == "cuda":
        torch.cuda.empty_cache()
    logger.info("Model unloaded, VRAM freed.")


def _tile_upscale(img_np: np.ndarray) -> np.ndarray:
    h, w = img_np.shape[:2]
    out_h, out_w = h * MODEL_SCALE, w * MODEL_SCALE
    output = np.zeros((out_h, out_w, 3), dtype=np.uint8)
    img_t = torch.from_numpy(img_np.astype(np.float32) / 255.0).permute(2, 0, 1).unsqueeze(0).to(DEVICE)
    tiles_y = max(1, (h + TILE_SIZE - 1) // TILE_SIZE)
    tiles_x = max(1, (w + TILE_SIZE - 1) // TILE_SIZE)
    for ty in range(tiles_y):
        for tx in range(tiles_x):
            y_start = min(ty * TILE_SIZE, max(0, h - TILE_SIZE))
            x_start = min(tx * TILE_SIZE, max(0, w - TILE_SIZE))
            y_end = min(y_start + TILE_SIZE, h)
            x_end = min(x_start + TILE_SIZE, w)
            tile = img_t[:, :, y_start:y_end, x_start:x_end]
            with torch.no_grad():
                out_tile = _model(tile)
            result = out_tile.squeeze(0).permute(1, 2, 0).cpu().numpy()
            result = np.clip(result * 255, 0, 255).astype(np.uint8)
            output[y_start * MODEL_SCALE:y_end * MODEL_SCALE, x_start * MODEL_SCALE:x_end * MODEL_SCALE] = result
    return output


def _cleanup_results():
    now = time.time()
    expired = [k for k, (_, ts) in _results.items() if now - ts > RESULT_TTL_SEC]
    for k in expired:
        del _results[k]


async def _idle_unloader():
    while True:
        await asyncio.sleep(30)
        _cleanup_results()
        if _model is not None and (time.monotonic() - _last_used) > IDLE_TIMEOUT_SEC:
            async with _lock:
                if _model is not None and (time.monotonic() - _last_used) > IDLE_TIMEOUT_SEC:
                    _unload_model()


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _unload_task
    _unload_task = asyncio.create_task(_idle_unloader())
    logger.info("Server started. Idle timeout: %ds", IDLE_TIMEOUT_SEC)
    yield
    _unload_task.cancel()
    _unload_model()
    logger.info("Server stopped.")


app = FastAPI(title="Upscale Server", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["POST", "GET"], allow_headers=["*"])


@app.get("/health")
async def health():
    return {"status": "ok", "device": DEVICE, "model_loaded": _model is not None}


@app.post("/upscale")
async def upscale(file: UploadFile = File(...)):
    global _last_used
    logger.info("Received upscale request: filename=%s, content_type=%s", file.filename, file.content_type)
    contents = await file.read()
    logger.info("Read %d bytes from upload", len(contents))
    if len(contents) == 0:
        raise HTTPException(status_code=400, detail="Empty file")
    try:
        img = Image.open(io.BytesIO(contents)).convert("RGB")
        logger.info("Image opened: %dx%d", img.width, img.height)
    except Exception as e:
        logger.error("Failed to open image: %s", e)
        raise HTTPException(status_code=400, detail=f"Invalid image: {e}")
    async with _lock:
        _load_model()
        _last_used = time.monotonic()
        img_np = np.array(img)
        try:
            output = _tile_upscale(img_np)
        except Exception as e:
            logger.exception("Upscale failed")
            raise HTTPException(status_code=500, detail=f"Upscale error: {e}")
    result_img = Image.fromarray(output)
    buf = io.BytesIO()
    result_img.save(buf, format="PNG")
    png_bytes = buf.getvalue()
    result_id = uuid.uuid4().hex[:12]
    _results[result_id] = (png_bytes, time.time())
    logger.info("Upscale complete, result_id=%s, %d bytes", result_id, len(png_bytes))
    return {"id": result_id}


@app.get("/result/{result_id}")
async def get_result(result_id: str):
    entry = _results.get(result_id)
    if entry is None:
        raise HTTPException(status_code=404, detail="Result not found or expired")
    png_bytes, _ = entry
    return StreamingResponse(io.BytesIO(png_bytes), media_type="image/png")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=7869, log_level="info")
