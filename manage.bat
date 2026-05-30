@echo off
chcp 65001 >nul 2>&1
:: Пропуск проверки прав, если уже повышены (передано как аргумент)
if "%~1"=="--elevated" goto :ELEVATED
:: Автоповышение до администратора, если ещё не повышено
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

:: --- Обработка CLI-аргументов ---
set CLI_MODE=0
if "%~1"=="" goto MENU
if "%~1"=="--elevated" goto MENU
set CLI_MODE=1
:: В CLI-режиме: выход после каждой команды. В интерактивном: пауза + меню.
if /i "%~1"=="install" goto FULL_INSTALL
if /i "%~1"=="start" goto START_SERVER
if /i "%~1"=="stop" goto STOP_SERVER
if /i "%~1"=="deps" goto INSTALL_DEPS
if /i "%~1"=="weights" goto DOWNLOAD_WEIGHTS
if /i "%~1"=="autostart" goto REGISTER_AUTOSTART
if /i "%~1"=="no-autostart" goto REMOVE_AUTOSTART
if /i "%~1"=="tampermonkey" goto INSTALL_TM
if /i "%~1"=="context-menu" goto INSTALL_CONTEXT_MENU
if /i "%~1"=="no-context-menu" goto REMOVE_CONTEXT_MENU
if /i "%~1"=="uninstall" goto UNINSTALL
if /i "%~1"=="status" goto STATUS
echo Неизвестная команда: %~1
echo.
echo Использование: manage.bat [команда]
echo.
echo Команды:
echo   install         Полная установка (venv + зависимости + веса + автозапуск + старт)
echo   start           Запустить сервер
echo   stop            Остановить сервер
echo   deps            Установить только зависимости
echo   weights         Загрузить только веса модели
echo   autostart       Зарегистрировать автозапуск при входе
echo   no-autostart    Удалить автозапуск
echo   context-menu    Добавить «Увеличить» в контекстное меню Проводника
echo   no-context-menu Удалить «Увеличить» из контекстного меню Проводника
echo   tampermonkey    Установить скрипт Tampermonkey
echo   uninstall       Остановить сервер и удалить автозапуск
echo   status          Показать статус сервера, автозапуска и контекстного меню
exit /b 1

:STATUS
set SERVER_STATUS=НЕ ЗАПУЩЕН
curl -s --max-time 2 %SERVER_URL%/health 2>nul | findstr /C:"status" >nul && set SERVER_STATUS=ЗАПУЩЕН
echo Сервер: %SERVER_STATUS% (%SERVER_URL%)
schtasks /query /tn "UpscaleServer" >nul 2>&1 && echo Автозапуск: ВКЛЮЧЁН || echo Автозапуск: ОТКЛЮЧЁН
reg query "HKCR\SystemFileAssociations\.png\shell\upscale" >nul 2>&1 && echo Контекстное меню: ВКЛЮЧЕНО || echo Контекстное меню: ОТКЛЮЧЕНО
exit /b 0

:MENU
cls
echo ============================================
echo   Upscale Context Menu - Менеджер
echo ============================================
echo.

:: --- Проверка статуса сервера ---
set SERVER_STATUS=НЕ ЗАПУЩЕН
curl -s --max-time 2 %SERVER_URL%/health 2>nul | findstr /C:"status" >nul && set SERVER_STATUS=ЗАПУЩЕН
echo   Сервер: %SERVER_STATUS% (%SERVER_URL%)

:: --- Проверка статуса автозапуска ---
schtasks /query /tn "UpscaleServer" >nul 2>&1 && (
    echo   Автозапуск: ВКЛЮЧЁН
) || (
    echo   Автозапуск: ОТКЛЮЧЁН
)

:: --- Проверка статуса контекстного меню ---
reg query "HKCR\SystemFileAssociations\.png\shell\upscale" >nul 2>&1 && (
    echo   Контекстное меню: ВКЛЮЧЕНО
) || (
    echo   Контекстное меню: ОТКЛЮЧЕНО
)
echo.

echo   [1] Полная установка (venv + зависимости + веса + автозапуск + старт)
echo   [2] Запустить сервер
echo   [3] Остановить сервер
echo   [4] Установить только зависимости
echo   [5] Загрузить только веса модели
echo   [6] Зарегистрировать автозапуск при входе
echo   [7] Удалить автозапуск
echo   [8] Установить скрипт Tampermonkey
echo   [9] Удалить (остановка + удаление автозапуска)
echo   [A] Добавить «Увеличить» в контекстное меню Проводника
echo   [B] Удалить «Увеличить» из контекстного меню Проводника
echo   [0] Выход
echo.
set /p CHOICE="Выберите пункт: "

if "%CHOICE%"=="1" goto FULL_INSTALL
if "%CHOICE%"=="2" goto START_SERVER
if "%CHOICE%"=="3" goto STOP_SERVER
if "%CHOICE%"=="4" goto INSTALL_DEPS
if "%CHOICE%"=="5" goto DOWNLOAD_WEIGHTS
if "%CHOICE%"=="6" goto REGISTER_AUTOSTART
if "%CHOICE%"=="7" goto REMOVE_AUTOSTART
if "%CHOICE%"=="8" goto INSTALL_TM
if "%CHOICE%"=="9" goto UNINSTALL
if /i "%CHOICE%"=="A" goto INSTALL_CONTEXT_MENU
if /i "%CHOICE%"=="B" goto REMOVE_CONTEXT_MENU
if "%CHOICE%"=="0" exit /b 0

echo Неверный пункт.
timeout /t 2 /nobreak >nul
goto MENU

:: ============================================
::  ПОЛНАЯ УСТАНОВКА
:: ============================================
:FULL_INSTALL
cls
echo ============================================
echo   Полная установка
echo ============================================
echo.

echo [1/5] Создание виртуального окружения...
if not exist "%VENV_DIR%" (
    python -m venv "%VENV_DIR%"
    if errorlevel 1 (
        echo ОШИБКА: Не удалось создать venv. Убедитесь, что Python 3.10+ установлен.
        goto END_SECTION
    )
)
call "%VENV_DIR%\Scripts\activate.bat"
echo       Готово.
echo.

echo [2/5] Установка PyTorch с CUDA 12.1...
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121 --quiet
if errorlevel 1 (
    echo ПРЕДУПРЕЖДЕНИЕ: Не удалось установить PyTorch с CUDA. Попытка установки CPU-версии...
    pip install torch torchvision --quiet
)

echo       Установка зависимостей сервера...
pip install -r "%SERVER_DIR%\requirements.txt" --quiet
if errorlevel 1 (
    echo ОШИБКА: Не удалось установить зависимости.
    goto END_SECTION
)
echo       Готово.
echo.

echo [3/5] Проверка весов модели...
if not exist "%WEIGHTS_FILE%" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SERVER_DIR%\download_weights.ps1"
    if errorlevel 1 (
        echo ОШИБКА: Не удалось загрузить веса.
        echo        Загрузите вручную: https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth
        echo        Поместите в: %SERVER_DIR%\weights\
        goto END_SECTION
    )
) else (
    echo       Веса уже присутствуют.
)
echo       Готово.
echo.

echo [4/5] Регистрация автозапуска при входе...
set VBS_PATH=%SERVER_DIR%\start-silent.vbs
schtasks /create /tn "UpscaleServer" /tr "wscript.exe \"%VBS_PATH%\"" /sc onlogon /rl limited /f
if !errorlevel! neq 0 (
    echo       ПРЕДУПРЕЖДЕНИЕ: Не удалось зарегистрировать автозапуск.
) else (
    echo       Автозапуск зарегистрирован.
)
echo       Готово.
echo.

echo [5/5] Запуск сервера увеличения...
call "%SERVER_DIR%\run-now.bat"
set /a TRIES=0
:WAIT_LOOP_FULL
if !TRIES! geq 15 goto WAIT_DONE_FULL
timeout /t 1 /nobreak >nul
curl -s --max-time 2 %SERVER_URL%/health >nul 2>&1 && goto SERVER_OK_FULL
set /a TRIES+=1
goto WAIT_LOOP_FULL
:SERVER_OK_FULL
echo       Сервер запущен на %SERVER_URL%
echo       Готово.
goto FULL_END
:WAIT_DONE_FULL
echo       ПРЕДУПРЕЖДЕНИЕ: Сервер не ответил в течение 15 сек.
echo       Проверьте ошибки в server\server.log.
echo       Готово.
:FULL_END
echo.
echo ============================================
echo   Полная установка завершена!
echo ============================================
echo.
echo Следующий шаг: Установите расширение Chrome:
echo   1. Откройте chrome://extensions
echo   2. Включите «Режим разработчика» (справа сверху)
echo   3. Нажмите «Загрузить распакованное расширение»
echo   4. Выберите: %PROJECT_DIR%extension
echo.
goto END_SECTION

:: ============================================
::  ЗАПУСК СЕРВЕРА
:: ============================================
:START_SERVER
cls
echo Запуск сервера...
call "%SERVER_DIR%\run-now.bat"
set /a TRIES=0
:WAIT_LOOP_START
if !TRIES! geq 15 goto WAIT_DONE_START
timeout /t 1 /nobreak >nul
curl -s --max-time 2 %SERVER_URL%/health >nul 2>&1 && goto SERVER_OK_START
set /a TRIES+=1
goto WAIT_LOOP_START
:SERVER_OK_START
echo Сервер запущен на %SERVER_URL%
goto START_END
:WAIT_DONE_START
echo ПРЕДУПРЕЖДЕНИЕ: Сервер не ответил в течение 15 сек.
echo Проверьте ошибки в server\server.log.
:START_END
goto END_SECTION

:: ============================================
::  ОСТАНОВКА СЕРВЕРА
:: ============================================
:STOP_SERVER
cls
echo Остановка сервера...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :7869 ^| findstr LISTENING') do (
    taskkill /F /PID %%a >nul 2>&1
)
echo Сервер остановлен.
goto END_SECTION

:: ============================================
::  УСТАНОВКА ЗАВИСИМОСТЕЙ
:: ============================================
:INSTALL_DEPS
cls
echo ============================================
echo   Установка зависимостей
echo ============================================
echo.

if not exist "%VENV_DIR%" (
    echo Создание виртуального окружения...
    python -m venv "%VENV_DIR%"
    if errorlevel 1 (
        echo ОШИБКА: Не удалось создать venv. Убедитесь, что Python 3.10+ установлен.
        goto END_SECTION
    )
)
call "%VENV_DIR%\Scripts\activate.bat"

echo Установка PyTorch с CUDA 12.1...
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121 --quiet
if errorlevel 1 (
    echo ПРЕДУПРЕЖДЕНИЕ: Не удалось установить PyTorch с CUDA. Попытка установки CPU-версии...
    pip install torch torchvision --quiet
)

echo Установка зависимостей сервера...
pip install -r "%SERVER_DIR%\requirements.txt" --quiet
if errorlevel 1 (
    echo ОШИБКА: Не удалось установить зависимости.
    goto END_SECTION
)

echo Готово.
goto END_SECTION

:: ============================================
::  ЗАГРУЗКА ВЕСОВ
:: ============================================
:DOWNLOAD_WEIGHTS
cls
echo ============================================
echo   Загрузка весов модели
echo ============================================
echo.

if exist "%WEIGHTS_FILE%" (
    echo Веса уже присутствуют:
    echo   %WEIGHTS_FILE%
    echo.
    set /p RE_DOWNLOAD="Загрузить повторно? (y/N): "
    if /i "!RE_DOWNLOAD!" neq "y" (
        goto END_SECTION
    )
    del "%WEIGHTS_FILE%"
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SERVER_DIR%\download_weights.ps1"
if errorlevel 1 (
    echo ОШИБКА: Не удалось загрузить веса.
    echo        Загрузите вручную: https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth
    echo        Поместите в: %SERVER_DIR%\weights\
)
echo.
goto END_SECTION

:: ============================================
::  РЕГИСТРАЦИЯ АВТОЗАПУСКА
:: ============================================
:REGISTER_AUTOSTART
cls
echo Регистрация автозапуска при входе...
set VBS_PATH=%SERVER_DIR%\start-silent.vbs
schtasks /create /tn "UpscaleServer" /tr "wscript.exe \"%VBS_PATH%\"" /sc onlogon /rl limited /f
if !errorlevel! neq 0 (
    echo ОШИБКА: Не удалось зарегистрировать автозапуск. Убедитесь, что запущено от имени администратора.
) else (
    echo Автозапуск успешно зарегистрирован.
)
goto END_SECTION

:: ============================================
::  УДАЛЕНИЕ АВТОЗАПУСКА
:: ============================================
:REMOVE_AUTOSTART
cls
echo Удаление автозапуска...
schtasks /delete /tn "UpscaleServer" /f
if !errorlevel! neq 0 (
    echo ПРЕДУПРЕЖДЕНИЕ: Задача автозапуска не найдена или не может быть удалена.
) else (
    echo Автозапуск удалён.
)
goto END_SECTION

:: ============================================
::  УСТАНОВКА КОНТЕКСТНОГО МЕНЮ ПРОВОДНИКА
:: ============================================
:INSTALL_CONTEXT_MENU
cls
echo ============================================
echo   Добавление «Увеличить» в контекстное меню Проводника
echo ============================================
echo.

set PS_SCRIPT=%SERVER_DIR%\upscale-file.ps1
set EXTENSIONS=.png .jpg .jpeg .webp .bmp .tiff .tif

for %%E in (%EXTENSIONS%) do (
    echo   Регистрация %%E ...
    reg add "HKCR\SystemFileAssociations\%%E\shell\upscale" /ve /d "Увеличить (4x)" /f >nul 2>&1
    reg add "HKCR\SystemFileAssociations\%%E\shell\upscale" /v Icon /d "%SERVER_DIR%\icon.ico,0" /f >nul 2>&1
    reg add "HKCR\SystemFileAssociations\%%E\shell\upscale\command" /ve /d "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%PS_SCRIPT%\" \"%%1\"" /f >nul 2>&1
)

echo.
echo Контекстное меню зарегистрировано для: %EXTENSIONS%
echo.
echo Правый клик по любому поддерживаемому изображению в Проводнике покажет «Увеличить (4x)».
goto END_SECTION

:: ============================================
::  УДАЛЕНИЕ КОНТЕКСТНОГО МЕНЮ ПРОВОДНИКА
:: ============================================
:REMOVE_CONTEXT_MENU
cls
echo ============================================
echo   Удаление «Увеличить» из контекстного меню Проводника
echo ============================================
echo.

set EXTENSIONS=.png .jpg .jpeg .webp .bmp .tiff .tif

for %%E in (%EXTENSIONS%) do (
    echo   Удаление %%E ...
    reg delete "HKCR\SystemFileAssociations\%%E\shell\upscale" /f >nul 2>&1
)

echo.
echo Контекстное меню удалено.
goto END_SECTION

:: ============================================
::  УСТАНОВКА СКРИПТА TAMPERMONKEY
:: ============================================
:INSTALL_TM
cls
echo ============================================
echo   Установка скрипта Tampermonkey
echo ============================================
echo.

echo Сборка скрипта Tampermonkey через Vite...
call npm run build:tm
if errorlevel 1 (
    echo ОШИБКА: Сборка не удалась. Убедитесь, что Node.js и npm установлены.
    echo        Выполните: npm install
    goto END_SECTION
)
echo       Готово.
echo.

set TM_SCRIPT=%PROJECT_DIR%tampermonkey\dist\upscale.user.js

if not exist "%TM_SCRIPT%" (
    echo ОШИБКА: Собранный скрипт не найден: %TM_SCRIPT%
    goto END_SECTION
)

set TM_URL=file:///%TM_SCRIPT:\=/%
echo Откройте эту ссылку в браузере для установки скрипта:
echo   %TM_URL%
echo.
echo Tampermonkey предложит установить его автоматически.

goto END_SECTION

:: ============================================
::  УДАЛЕНИЕ
:: ============================================
:UNINSTALL
cls
echo ============================================
echo   Upscale Context Menu - Удаление
echo ============================================
echo.

echo [1/3] Остановка сервера увеличения...
taskkill /F /IM python.exe /FI "WINDOWTITLE eq *app.py*" >nul 2>&1
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":7869" ^| findstr "LISTENING"') do (
    taskkill /F /PID %%a >nul 2>&1
)
echo       Готово.
echo.

echo [2/3] Удаление задачи автозапуска...
schtasks /delete /tn "UpscaleServer" /f >nul 2>&1
if errorlevel 1 (
    echo       Задача автозапуска не найдена (уже удалена).
) else (
    echo       Автозапуск удалён.
)
echo       Готово.
echo.

echo [3/3] Удаление контекстного меню Проводника...
set EXTENSIONS=.png .jpg .jpeg .webp .bmp .tiff .tif
for %%E in (%EXTENSIONS%) do (
    reg delete "HKCR\SystemFileAssociations\%%E\shell\upscale" /f >nul 2>&1
)
echo       Готово.
echo.

echo ============================================
echo   Удаление завершено!
echo ============================================
echo.
echo Следующие компоненты НЕ были удалены автоматически:
echo   - Виртуальное окружение: %SERVER_DIR%\.venv
echo   - Веса модели:          %SERVER_DIR%\weights
echo   - Расширение Chrome (удалите вручную в chrome://extensions)
echo.
echo Для полного удаления всего, удалите папку:
echo   %PROJECT_DIR%
echo.
goto END_SECTION

:: ============================================
::  Вспомогательная метка END_SECTION (используйте goto, не call)
:: ============================================
:END_SECTION
if "%CLI_MODE%"=="1" exit /b 0
pause
goto MENU
