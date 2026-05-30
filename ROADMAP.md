# Upscale Context Menu — Roadmap

Локальный GPU-сервер + три клиента (Explorer, Chrome, Tampermonkey) для апскейла изображений через контекстное меню.
Качество не хуже 4x-UltraSharp из SD WebUI, без запуска полного SD pipeline.

## Архитектура

- **Explorer Context Menu** — ПКМ по файлу → «Upscale (4x)», PowerShell-скрипт отправляет файл на сервер, результат открывается в браузере
- **Chrome Extension (Manifest V3)** — контекстное меню «Апскейлнуть», fetch изображения из кэша браузера, POST binary на локальный сервер
- **Tampermonkey Userscript** — аналог расширения для любого браузера, отслеживание последнего hovered-изображения через mouseover
- **Shared lib/** — общий API-клиент (health check + upscale) для extension и tampermonkey
- **Python-сервер (FastAPI + uvicorn)** — lazy load модели Real-ESRGAN, выгрузка из VRAM по таймауту простоя
- **Модель** — Real-ESRGAN с весами 4x-UltraSharp
- **manage.bat** — единый инструмент управления (установка, запуск, автозапуск, контекстное меню, CLI)
- **Сервер всегда запущен** через Task Scheduler, модель выгружается из VRAM при простое (~30 МБ RAM idle, GPU свободен)

## Этапы

### 1. Python-сервер (FastAPI + uvicorn) ✅
- [x] Endpoint `POST /upscale` принимает multipart/form-data с изображением
- [x] Lazy load модели Real-ESRGAN при первом запросе
- [x] Idle timer: выгрузка модели из VRAM через 5 минут простоя (`del model; torch.cuda.empty_cache()`)
- [x] CORS заголовки для `chrome-extension://*`
- [x] Health-check endpoint `GET /health`

### 2. Chrome Extension (Manifest V3) ✅
- [x] Context menu «Апскейлнуть» для всех `<img>` элементов
- [x] Content script: уведомления об ошибках
- [x] Background service worker: fetch blob из кэша → POST на `http://localhost:7869/upscale`
- [x] Отображение результата: открытие в новой вкладке
- [x] Обработка ошибок: уведомление если сервер не запущен

### 3. Модель апскейла ✅
- [x] Скачать веса 4x-UltraSharp (~64 МБ)
- [x] Интеграция через `realesrgan` / `basicsr` + PyTorch CUDA 12.1
- [x] Tile-based inference (tile=512) для больших изображений

### 4. Автозапуск и управление ✅
- [x] `manage.bat` — единый CLI + интерактивное меню
- [x] Windows Task Scheduler: автозапуск при входе
- [x] Полная установка одним действием (`manage.bat install`)
- [x] README.md с инструкцией

### 5. Tampermonkey Userscript ✅
- [x] Отслеживание последнего hovered-изображения через mouseover
- [x] Vite-сборка в `tampermonkey/dist/upscale.user.js`
- [x] Установка через `manage.bat tampermonkey`
- [x] Shared lib/ для переиспользования API-клиента

### 6. Explorer Context Menu ✅
- [x] Регистрация «Upscale (4x)» для .png/.jpg/.jpeg/.webp/.bmp/.tiff/.tif
- [x] PowerShell-скрипт `upscale-file.ps1` с multipart/form-data
- [x] Управление через `manage.bat context-menu` / `no-context-menu`
- [x] Очистка реестра при uninstall

### 7. Тестирование и полировка ⏳
- [ ] Сравнение качества с SD WebUI 4x-UltraSharp (должно быть идентично)
- [ ] Тесты на различных размерах изображений
- [ ] Проверка выгрузки VRAM после простоя
- [ ] UX: прогресс-индикатор, обработка больших файлов
