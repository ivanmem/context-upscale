@echo off
cd /d "%~dp0"
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :7869 ^| findstr LISTENING') do taskkill /F /PID %%a >nul 2>&1
wscript.exe "%~dp0start-silent.vbs"
