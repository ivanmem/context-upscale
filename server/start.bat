@echo off
cd /d "%~dp0"
call .venv\Scripts\activate.bat
echo [Upscale Server] Starting on http://127.0.0.1:7869
python app.py
pause
