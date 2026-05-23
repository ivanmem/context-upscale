@echo off
set TASK_NAME=UpscaleServer

echo [Upscale Server] Removing scheduled task "%TASK_NAME%"...
schtasks /delete /tn "%TASK_NAME%" /f
if %errorlevel% equ 0 (
    echo [Upscale Server] Task removed.
) else (
    echo [Upscale Server] Task not found or removal failed.
)
pause
