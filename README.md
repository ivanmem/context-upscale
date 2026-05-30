# Upscale Context Menu

Right-click any image → **Upscale** → result opens in a new tab.

A lightweight toolset — Explorer context menu, Chrome extension, and Tampermonkey userscript — for upscaling images using a local GPU server powered by Real-ESRGAN 4x-UltraSharp. Browser clients send binary data (not URLs), avoiding double downloads and regional blocking issues.

## Features

- **Explorer Context Menu** — right-click any image file in Windows Explorer → Upscale (4x)
- **Chrome Extension** — native context menu integration (MV3)
- **Tampermonkey Userscript** — works in any browser with Tampermonkey
- **Local GPU Server** — FastAPI + Real-ESRGAN on your own hardware
- **Lazy Model Loading** — model loads on first request, unloads from VRAM after 5 min idle
- **Tiled Upscaling** — handles large images without OOM
- **Zero Cloud Dependencies** — everything runs locally

## Architecture

```
┌─────────────────┐   multipart/form   ┌──────────────────┐
│  Explorer Menu  │ ── POST /upscale ─→ │                  │
│  Chrome Ext /   │ ── POST /upscale ─→ │  FastAPI Server   │
│  Tampermonkey   │ ←── JPEG result ── │  Real-ESRGAN 4x   │
└─────────────────┘                     │  localhost:7869   │
                                        └──────────────────┘
```

- Browser extracts the image directly from the page (no re-download)
- Binary data is sent to the local server via `multipart/form-data`
- Server upscales on GPU and returns a JPEG
- Model auto-unloads from VRAM after idle timeout (`torch.cuda.empty_cache()`)
- Server uses ~30 MB RAM when idle, GPU is free

## Requirements

- Windows 10/11
- NVIDIA GPU with CUDA support (RTX 30xx/40xx recommended)
- NVIDIA Driver ≥ 530.xx
- Chrome or Chromium-based browser (for extension)
- Tampermonkey extension (for userscript alternative)
- ~4 GB free disk space (PyTorch + CUDA + model weights)

## Installation

### 1. Server

Run `manage.bat` (automatically requests admin privileges):

```bat
manage.bat
```

Select option **[1] Full install**. This will:
- Create a virtual environment in `server/.venv`
- Install PyTorch with CUDA 12.1 and all dependencies
- Download 4x-UltraSharp weights (~64 MB)
- Register the server for autostart on Windows login

The server runs silently in the background. To restart manually: `server/run-now.bat`

### 2a. Explorer Context Menu (Optional)

Run `manage.bat` → option **[A] Add Upscale to Explorer context menu**.

This registers "Upscale (4x)" in the right-click menu for `.png`, `.jpg`, `.jpeg`, `.webp`, `.bmp`, `.tiff`, `.tif` files. The upscaled result opens in your default browser. To remove: option **[B]** or `manage.bat no-context-menu`.

### 2b. Chrome Extension

1. Open `chrome://extensions`
2. Enable **Developer mode** (toggle in top-right)
3. Click **Load unpacked**
4. Select the `extension` folder from this project

Done. Right-click any image to see the **Upscale** menu item.

### 2c. Tampermonkey Userscript (Alternative)

1. Install [Tampermonkey](https://www.tampermonkey.net/)
2. Run `manage.bat` → option **[8] Install Tampermonkey script**
3. Or manually install from `tampermonkey/dist/upscale.user.js`

> **Note:** The userscript tracks the last hovered image via `mouseover`. Hover over an image before selecting the menu command. When the context menu is open, mouse events are blocked by the browser, so the target won't change accidentally.

## Usage

| Action | Result |
|---|---|
| Right-click image → **Upscale** | Opens upscaled image in new tab |
| First upscale after idle | ~2-3s (model loading into VRAM) |
| Subsequent upscales | Near-instant |
| Server health check | `GET http://127.0.0.1:7869/health` |

## Management

### Interactive Menu

Run `manage.bat` without arguments:

| Option | Action |
|---|---|
| [1] | Full install (venv + deps + weights + autostart + start) |
| [2] | Start server |
| [3] | Stop server |
| [4] | Install dependencies |
| [5] | Download model weights |
| [6] | Enable autostart |
| [7] | Disable autostart |
| [8] | Install Tampermonkey script |
| [9] | Uninstall (stop + disable autostart + remove context menu) |
| [A] | Add Upscale to Explorer context menu |
| [B] | Remove Upscale from Explorer context menu |

### CLI Mode

```bat
manage.bat start         # Start server
manage.bat stop          # Stop server
manage.bat status        # Server & autostart status
manage.bat install       # Full installation
manage.bat deps          # Install Python dependencies
manage.bat weights       # Download model weights
manage.bat autostart     # Enable autostart
manage.bat no-autostart  # Disable autostart
manage.bat tampermonkey    # Build & install Tampermonkey script
manage.bat context-menu    # Add Explorer context menu
manage.bat no-context-menu # Remove Explorer context menu
manage.bat uninstall       # Stop + disable autostart + remove context menu
```

## Project Structure

```
context-upscale/
├── extension/              # Chrome extension (MV3)
│   ├── manifest.json
│   ├── background.js       # Context menu + fetch + POST
│   └── content.js          # Toast notifications + result display
├── tampermonkey/           # Tampermonkey userscript
│   ├── entry.js            # Script source (Vite entry point)
│   └── dist/               # Built userscript
├── lib/                    # Shared logic (used by both clients)
│   └── upscale.js          # Health check + upscale API client
├── server/                 # Python GPU server
│   ├── app.py              # FastAPI + Real-ESRGAN
│   ├── upscale-file.ps1    # Explorer context menu handler
│   ├── requirements.txt
│   ├── run-now.bat         # Restart server (hidden)
│   ├── start-silent.vbs    # Silent launch wrapper
│   └── weights/            # Model weights (gitignored)
├── manage.bat              # Unified management tool
├── vite.config.tm.js       # Vite config for Tampermonkey build
└── package.json
```

## Troubleshooting

**"Upscale server is not running"**
→ Run `server/run-now.bat`. Check status: `curl http://127.0.0.1:7869/health`. Logs: `server/server.log`

**Health shows `device: cpu`**
→ Reinstall PyTorch with CUDA:
```bat
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121 --force-reinstall
```

**Slow first upscale**
→ Expected: model loads into VRAM on first request (~2-3s). Subsequent requests are instant.

**Tampermonkey: "Tainted canvas" error**
→ Normal fallback behavior. The script tries canvas extraction first, then falls back to `fetch()` in page context.

**Want to completely remove**
1. Run `manage.bat` → option [9]
2. Remove extension in `chrome://extensions`
3. Delete project folder

## License

MIT
