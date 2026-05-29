@echo off
:: Auto-elevate to admin if not already
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)
setlocal enabledelayedexpansion

echo ============================================
echo   Upscale Context Menu - Setup
echo ============================================
echo.

set PROJECT_DIR=%~dp0
set SERVER_DIR=%PROJECT_DIR%server
set VENV_DIR=%SERVER_DIR%\.venv
set WEIGHTS_FILE=%SERVER_DIR%\weights\4x-UltraSharp.pth

:: --- Step 1: Create venv ---
echo [1/5] Creating virtual environment...
if not exist "%VENV_DIR%" (
    python -m venv "%VENV_DIR%"
    if errorlevel 1 (
        echo ERROR: Failed to create venv. Make sure Python 3.10+ is installed.
        pause
        exit /b 1
    )
)
call "%VENV_DIR%\Scripts\activate.bat"
echo       Done.
echo.

:: --- Step 2: Install dependencies with CUDA ---
echo [2/5] Installing PyTorch with CUDA 12.1...
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121 --quiet
if errorlevel 1 (
    echo WARNING: CUDA PyTorch install failed. Trying CPU version...
    pip install torch torchvision --quiet
)

echo       Installing server dependencies...
pip install -r "%SERVER_DIR%\requirements.txt" --quiet
if errorlevel 1 (
    echo ERROR: Failed to install dependencies.
    pause
    exit /b 1
)
echo       Done.
echo.

:: --- Step 3: Download weights ---
echo [3/5] Checking model weights...
if not exist "%WEIGHTS_FILE%" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SERVER_DIR%\download_weights.ps1"
    if errorlevel 1 (
        echo ERROR: Failed to download weights.
        echo        Download manually: https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth
        echo        Place in: %SERVER_DIR%\weights\
        pause
        exit /b 1
    )
) else (
    echo       Weights already present.
)
echo       Done.
echo.

:: --- Step 4: Register autostart (requires admin) ---
echo [4/5] Registering auto-start on login (requires admin)...
set VBS_PATH=%SERVER_DIR%\start-silent.vbs
schtasks /create /tn "UpscaleServer" /tr "wscript.exe \"%VBS_PATH%\"" /sc onlogon /rl limited /f
if !errorlevel! neq 0 (
    echo       WARNING: Could not register auto-start. Run install-autostart.bat as admin later.
) else (
    echo       Auto-start registered.
)
echo       Done.
echo.

:: --- Step 5: Start server now ---
echo [5/5] Starting upscale server...
call "%SERVER_DIR%\run-now.bat"
:: Wait up to 15 seconds for the server to become healthy
set /a TRIES=0
:WAIT_LOOP
if !TRIES! geq 15 goto WAIT_DONE
timeout /t 1 /nobreak >nul
curl -s http://127.0.0.1:7869/health >nul 2>&1 && goto SERVER_OK
set /a TRIES+=1
goto WAIT_LOOP
:SERVER_OK
echo       Server is running on http://127.0.0.1:7869
echo       Done.
goto STEP5_END
:WAIT_DONE
echo       WARNING: Server did not respond within 15s.
echo       Check server\server.log for errors.
echo       Done.
:STEP5_END
echo.

echo ============================================
echo   Setup complete!
echo ============================================
echo.
echo Next step: Install the Chrome extension:
echo   1. Open chrome://extensions
echo   2. Enable "Developer mode" (top right)
echo   3. Click "Load unpacked"
echo   4. Select: %PROJECT_DIR%extension
echo.
echo The server is running now and will auto-start on login.
echo.
pause
