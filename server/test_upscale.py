"""Automated test for the upscale server."""
import io
import sys
import time
import requests
from PIL import Image

SERVER = "http://127.0.0.1:7869"

def test_health():
    print("[1/5] Health check...", end=" ")
    r = requests.get(f"{SERVER}/health", timeout=5)
    assert r.status_code == 200, f"HTTP {r.status_code}"
    data = r.json()
    assert data["status"] == "ok"
    print(f"OK (device={data['device']}, model_loaded={data['model_loaded']})")

def test_empty_file():
    print("[2/5] Empty file rejection...", end=" ")
    r = requests.post(f"{SERVER}/upscale", files={"file": ("empty.png", b"", "image/png")}, timeout=5)
    assert r.status_code == 400, f"Expected 400, got {r.status_code}"
    print(f"OK ({r.json()['detail']})")

def test_invalid_image():
    print("[3/5] Invalid image rejection...", end=" ")
    r = requests.post(f"{SERVER}/upscale", files={"file": ("bad.png", b"not an image", "image/png")}, timeout=5)
    assert r.status_code == 400, f"Expected 400, got {r.status_code}"
    print(f"OK ({r.json()['detail'][:60]})")

def test_upscale_and_result():
    print("[4/5] Upscale 64x64 -> 256x256...", end=" ", flush=True)
    img = Image.new("RGB", (64, 64), (255, 0, 0))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)

    t0 = time.time()
    r = requests.post(f"{SERVER}/upscale", files={"file": ("test.png", buf, "image/png")}, timeout=120)
    elapsed = time.time() - t0

    if r.status_code != 200:
        print(f"FAILED (HTTP {r.status_code}: {r.text[:300]})")
        return False

    data = r.json()
    result_id = data.get("id")
    if not result_id:
        print(f"FAILED (no id in response: {data})")
        return False
    print(f"OK ({elapsed:.1f}s, id={result_id})")

    print("[5/5] Fetch result by ID...", end=" ", flush=True)
    r2 = requests.get(f"{SERVER}/result/{result_id}", timeout=10)
    if r2.status_code != 200:
        print(f"FAILED (HTTP {r2.status_code}: {r2.text[:300]})")
        return False

    result = Image.open(io.BytesIO(r2.content))
    w, h = result.size
    if w != 256 or h != 256:
        print(f"FAILED (size {w}x{h}, expected 256x256)")
        return False
    print(f"OK ({len(r2.content)} bytes, {w}x{h})")
    return True

if __name__ == "__main__":
    try:
        test_health()
        test_empty_file()
        test_invalid_image()
        ok = test_upscale_and_result()
        print()
        if ok:
            print("ALL TESTS PASSED")
        else:
            print("UPSCALE TEST FAILED")
            sys.exit(1)
    except Exception as e:
        print(f"\nTEST ERROR: {e}")
        sys.exit(1)
