@echo off
:: Skip elevation check if already elevated (passed as argument)
if "%~1"=="--elevated" goto :ELEVATED
:: Auto-elevate to admin if not already
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process cmd -ArgumentList '/k \"%~f0\" --elevated' -Verb RunAs"
    exit /b 0
)
:ELEVATED
setlocal enabledelayedexpansion

set PROJECT_DIR=%~dp0
set SERVER_DIR=%PROJECT_DIR%server
set VENV_DIR=%SERVER_DIR%\.venv
set WEIGHTS_FILE=%SERVER_DIR%\weights\4x-UltraSharp.pth
set SERVER_URL=http://127.0.0.1:7869

:: --- CLI argument handling ---
set CLI_MODE=0
if "%~1"=="" goto MENU
if "%~1"=="--elevated" goto MENU
set CLI_MODE=1
:: In CLI mode: exit after each command. In interactive: pause + menu.
if /i "%~1"=="install" goto FULL_INSTALL
if /i "%~1"=="start" goto START_SERVER
if /i "%~1"=="stop" goto STOP_SERVER
if /i "%~1"=="deps" goto INSTALL_DEPS
if /i "%~1"=="weights" goto DOWNLOAD_WEIGHTS
if /i "%~1"=="autostart" goto REGISTER_AUTOSTART
if /i "%~1"=="no-autostart" goto REMOVE_AUTOSTART
if /i "%~1"=="tampermonkey" goto INSTALL_TM
if /i "%~1"=="uninstall" goto UNINSTALL
if /i "%~1"=="status" goto STATUS
echo Unknown command: %~1
echo.
echo Usage: manage.bat [command]
echo.
echo Commands:
echo   install       Full install (venv + deps + weights + autostart + start)
echo   start         Start server
echo   stop          Stop server
echo   deps          Install dependencies only
echo   weights       Download model weights only
echo   autostart     Register auto-start on login
echo   no-autostart  Remove auto-start
echo   tampermonkey  Install Tampermonkey script
echo   uninstall     Stop server and remove auto-start
echo   status        Show server and autostart status
exit /b 1

:STATUS
curl -sf --max-time 2 %SERVER_URL%/health >nul 2>&1 && echo Server: RUNNING (%SERVER_URL%) || echo Server: NOT RUNNING
schtasks /query /tn "UpscaleServer" >nul 2>&1 && echo Autostart: ENABLED || echo Autostart: DISABLED
exit /b 0

:MENU
cls
echo ============================================
echo   Upscale Context Menu - Manager
echo ============================================
echo.

:: --- Server status check ---
echo Checking server status...
curl -sf --max-time 2 %SERVER_URL%/health >nul 2>&1 && echo   Server: RUNNING (%SERVER_URL%) || echo   Server: NOT RUNNING

:: --- Autostart status check ---
schtasks /query /tn "UpscaleServer" >nul 2>&1 && (
    echo   Autostart: ENABLED
) || (
    echo   Autostart: DISABLED
)
echo.

echo   [1] Full install (venv + deps + weights + autostart + start)
echo   [2] Start server
echo   [3] Stop server
echo   [4] Install dependencies only
echo   [5] Download model weights only
echo   [6] Register auto-start on login
echo   [7] Remove auto-start
echo   [8] Install Tampermonkey script
echo   [9] Uninstall (stop + remove autostart)
echo   [0] Exit
echo.
set /p CHOICE="Select an option: "

if "%CHOICE%"=="1" goto FULL_INSTALL
if "%CHOICE%"=="2" goto START_SERVER
if "%CHOICE%"=="3" goto STOP_SERVER
if "%CHOICE%"=="4" goto INSTALL_DEPS
if "%CHOICE%"=="5" goto DOWNLOAD_WEIGHTS
if "%CHOICE%"=="6" goto REGISTER_AUTOSTART
if "%CHOICE%"=="7" goto REMOVE_AUTOSTART
if "%CHOICE%"=="8" goto INSTALL_TM
if "%CHOICE%"=="9" goto UNINSTALL
if "%CHOICE%"=="0" exit /b 0

echo Invalid option.
timeout /t 2 /nobreak >nul
goto MENU

:: ============================================
::  FULL INSTALL
:: ============================================
:FULL_INSTALL
cls
echo ============================================
echo   Full Installation
echo ============================================
echo.

echo [1/5] Creating virtual environment...
if not exist "%VENV_DIR%" (
    python -m venv "%VENV_DIR%"
    if errorlevel 1 (
        echo ERROR: Failed to create venv. Make sure Python 3.10+ is installed.
        goto END_SECTION
    )
)
call "%VENV_DIR%\Scripts\activate.bat"
echo       Done.
echo.

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
    goto END_SECTION
)
echo       Done.
echo.

echo [3/5] Checking model weights...
if not exist "%WEIGHTS_FILE%" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SERVER_DIR%\download_weights.ps1"
    if errorlevel 1 (
        echo ERROR: Failed to download weights.
        echo        Download manually: https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth
        echo        Place in: %SERVER_DIR%\weights\
        goto END_SECTION
    )
) else (
    echo       Weights already present.
)
echo       Done.
echo.

echo [4/5] Registering auto-start on login...
set VBS_PATH=%SERVER_DIR%\start-silent.vbs
schtasks /create /tn "UpscaleServer" /tr "wscript.exe \"%VBS_PATH%\"" /sc onlogon /rl limited /f
if !errorlevel! neq 0 (
    echo       WARNING: Could not register auto-start.
) else (
    echo       Auto-start registered.
)
echo       Done.
echo.

echo [5/5] Starting upscale server...
call "%SERVER_DIR%\run-now.bat"
set /a TRIES=0
:WAIT_LOOP_FULL
if !TRIES! geq 15 goto WAIT_DONE_FULL
timeout /t 1 /nobreak >nul
curl -s --max-time 2 %SERVER_URL%/health >nul 2>&1 && goto SERVER_OK_FULL
set /a TRIES+=1
goto WAIT_LOOP_FULL
:SERVER_OK_FULL
echo       Server is running on %SERVER_URL%
echo       Done.
goto FULL_END
:WAIT_DONE_FULL
echo       WARNING: Server did not respond within 15s.
echo       Check server\server.log for errors.
echo       Done.
:FULL_END
echo.
echo ============================================
echo   Full installation complete!
echo ============================================
echo.
echo Next step: Install the Chrome extension:
echo   1. Open chrome://extensions
echo   2. Enable "Developer mode" (top right)
echo   3. Click "Load unpacked"
echo   4. Select: %PROJECT_DIR%extension
echo.
goto END_SECTION

:: ============================================
::  START SERVER
:: ============================================
:START_SERVER
cls
echo Starting server...
call "%SERVER_DIR%\run-now.bat"
set /a TRIES=0
:WAIT_LOOP_START
if !TRIES! geq 15 goto WAIT_DONE_START
timeout /t 1 /nobreak >nul
curl -s --max-time 2 %SERVER_URL%/health >nul 2>&1 && goto SERVER_OK_START
set /a TRIES+=1
goto WAIT_LOOP_START
:SERVER_OK_START
echo Server is running on %SERVER_URL%
goto START_END
:WAIT_DONE_START
echo WARNING: Server did not respond within 15s.
echo Check server\server.log for errors.
:START_END
goto END_SECTION

:: ============================================
::  STOP SERVER
:: ============================================
:STOP_SERVER
cls
echo Stopping server...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :7869 ^| findstr LISTENING') do (
    taskkill /F /PID %%a >nul 2>&1
)
echo Server stopped.
goto END_SECTION

:: ============================================
::  INSTALL DEPENDENCIES
:: ============================================
:INSTALL_DEPS
cls
echo ============================================
echo   Installing Dependencies
echo ============================================
echo.

if not exist "%VENV_DIR%" (
    echo Creating virtual environment...
    python -m venv "%VENV_DIR%"
    if errorlevel 1 (
        echo ERROR: Failed to create venv. Make sure Python 3.10+ is installed.
        goto END_SECTION
    )
)
call "%VENV_DIR%\Scripts\activate.bat"

echo Installing PyTorch with CUDA 12.1...
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121 --quiet
if errorlevel 1 (
    echo WARNING: CUDA PyTorch install failed. Trying CPU version...
    pip install torch torchvision --quiet
)

echo Installing server dependencies...
pip install -r "%SERVER_DIR%\requirements.txt" --quiet
if errorlevel 1 (
    echo ERROR: Failed to install dependencies.
    goto END_SECTION
)

echo Done.
goto END_SECTION

:: ============================================
::  DOWNLOAD WEIGHTS
:: ============================================
:DOWNLOAD_WEIGHTS
cls
echo ============================================
echo   Downloading Model Weights
echo ============================================
echo.

if exist "%WEIGHTS_FILE%" (
    echo Weights already present at:
    echo   %WEIGHTS_FILE%
    echo.
    set /p RE_DOWNLOAD="Re-download? (y/N): "
    if /i "!RE_DOWNLOAD!" neq "y" (
        goto END_SECTION
    )
    del "%WEIGHTS_FILE%"
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SERVER_DIR%\download_weights.ps1"
if errorlevel 1 (
    echo ERROR: Failed to download weights.
    echo        Download manually: https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth
    echo        Place in: %SERVER_DIR%\weights\
)
echo.
goto END_SECTION

:: ============================================
::  REGISTER AUTOSTART
:: ============================================
:REGISTER_AUTOSTART
cls
echo Registering auto-start on login...
set VBS_PATH=%SERVER_DIR%\start-silent.vbs
schtasks /create /tn "UpscaleServer" /tr "wscript.exe \"%VBS_PATH%\"" /sc onlogon /rl limited /f
if !errorlevel! neq 0 (
    echo ERROR: Could not register auto-start. Make sure you run as admin.
) else (
    echo Auto-start registered successfully.
)
goto END_SECTION

:: ============================================
::  REMOVE AUTOSTART
:: ============================================
:REMOVE_AUTOSTART
cls
echo Removing auto-start...
schtasks /delete /tn "UpscaleServer" /f
if !errorlevel! neq 0 (
    echo WARNING: Auto-start task was not found or could not be removed.
) else (
    echo Auto-start removed.
)
goto END_SECTION

:: ============================================
::  INSTALL TAMPERMONKEY SCRIPT
:: ============================================
:INSTALL_TM
cls
echo ============================================
echo   Install Tampermonkey Script
echo ============================================
echo.

echo Building Tampermonkey script with Vite...
call npm run build:tm
if errorlevel 1 (
    echo ERROR: Build failed. Make sure Node.js and npm are installed.
    echo        Run: npm install
    goto END_SECTION
)
echo       Done.
echo.

set TM_SCRIPT=%PROJECT_DIR%tampermonkey\dist\upscale.user.js

if not exist "%TM_SCRIPT%" (
    echo ERROR: Built script not found at %TM_SCRIPT%
    goto END_SECTION
)

echo Opening Tampermonkey script in browser...
echo.
echo If Tampermonkey is installed, it will prompt you to install the script.
echo If nothing happens, open this URL manually:
echo   file:///%TM_SCRIPT%
echo.
start "" "%TM_SCRIPT%"

goto END_SECTION

:: ============================================
::  UNINSTALL
:: ============================================
:UNINSTALL
cls
echo ============================================
echo   Upscale Context Menu - Uninstall
echo ============================================
echo.

echo [1/2] Stopping upscale server...
taskkill /F /IM python.exe /FI "WINDOWTITLE eq *app.py*" >nul 2>&1
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":7869" ^| findstr "LISTENING"') do (
    taskkill /F /PID %%a >nul 2>&1
)
echo       Done.
echo.

echo [2/2] Removing auto-start task...
schtasks /delete /tn "UpscaleServer" /f >nul 2>&1
if errorlevel 1 (
    echo       No auto-start task found (already removed).
) else (
    echo       Auto-start removed.
)
echo       Done.
echo.

echo ============================================
echo   Uninstall complete!
echo ============================================
echo.
echo The following were NOT deleted automatically:
echo   - Virtual environment: %SERVER_DIR%\.venv
echo   - Model weights:       %SERVER_DIR%\weights
echo   - Chrome extension (remove manually from chrome://extensions)
echo.
echo To fully remove everything, delete the folder:
echo   %PROJECT_DIR%
echo.
goto END_SECTION

:: ============================================
::  END SECTION helper (use goto, not call)
:: ============================================
:END_SECTION
if "%CLI_MODE%"=="1" exit /b 0
pause
goto MENU