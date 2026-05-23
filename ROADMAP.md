# Upscale Context Menu — Roadmap

Chrome-расширение + локальный GPU-сервер для апскейла изображений через контекстное меню.
Качество не хуже 4x-UltraSharp из SD WebUI, без запуска полного SD pipeline.

## Архитектура

- **Chrome Extension (Manifest V3)** — контекстное меню «Апскейлнуть», fetch изображения из кэша браузера, POST binary на локальный сервер
- **Python-сервер (FastAPI + uvicorn)** — lazy load модели Real-ESRGAN, выгрузка из VRAM по таймауту простоя
- **Модель** — Real-ESRGAN с весами 4x-UltraSharp
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

### 4. Автозапуск и установка ✅
- [x] Windows Task Scheduler: `install-autostart.bat` / `remove-autostart.bat`
- [x] Скрипт запуска `start.bat` с автоустановкой зависимостей
- [x] `setup.bat` — полная установка одним скриптом (venv + CUDA + веса + автозапуск)
- [x] README.md с инструкцией

### 5. Тестирование и полировка ⏳
- [ ] Сравнение качества с SD WebUI 4x-UltraSharp (должно быть идентично)
- [ ] Тесты на различных размерах изображений
- [ ] Проверка выгрузки VRAM после простоя
- [ ] UX: прогресс-индикатор, обработка больших файлов
