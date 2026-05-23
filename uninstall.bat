@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   Upscale Context Menu - Uninstall
echo ============================================
echo.

set PROJECT_DIR=%~dp0
set SERVER_DIR=%PROJECT_DIR%server

:: --- Step 1: Stop server ---
echo [1/3] Stopping upscale server...
taskkill /F /IM python.exe /FI "WINDOWTITLE eq *app.py*" >nul 2>&1
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":7869" ^| findstr "LISTENING"') do (
    taskkill /F /PID %%a >nul 2>&1
)
echo       Done.
echo.

:: --- Step 2: Remove auto-start task ---
echo [2/3] Removing auto-start task...
schtasks /delete /tn "UpscaleServer" /f >nul 2>&1
if errorlevel 1 (
    echo       No auto-start task found (already removed).
) else (
    echo       Auto-start removed.
)
echo       Done.
echo.

:: --- Step 3: Ask about cleanup ---
echo [3/3] Cleanup options:
echo.
echo   The following will NOT be deleted automatically:
echo     - Virtual environment: %SERVER_DIR%\.venv
echo     - Model weights:       %SERVER_DIR%\weights
echo     - Chrome extension (remove manually from chrome://extensions)
echo.
echo   To fully remove everything, delete the folder:
echo     %PROJECT_DIR%
echo.

echo ============================================
echo   Uninstall complete!
echo ============================================
echo.
echo Don't forget to remove the extension from Chrome:
echo   1. Open chrome://extensions
echo   2. Find "Upscale Context Menu"
echo   3. Click "Remove"
echo.
pause
