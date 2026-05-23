@echo off
:: Register upscale server as a Task Scheduler task (runs at user login)
set TASK_NAME=UpscaleServer
set SCRIPT_PATH=%~dp0start.bat

echo [Upscale Server] Creating scheduled task "%TASK_NAME%"...
schtasks /create /tn "%TASK_NAME%" /tr "\"%SCRIPT_PATH%\"" /sc onlogon /rl limited /f
if %errorlevel% equ 0 (
    echo [Upscale Server] Task created successfully.
    echo [Upscale Server] Server will auto-start on login.
) else (
    echo [Upscale Server] Failed to create task. Try running as administrator.
)
pause
