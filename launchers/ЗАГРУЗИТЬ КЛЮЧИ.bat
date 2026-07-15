@echo off
REM Двойной клик — ввести/обновить API-ключи (OpenAI + Claude). Сохраняются постоянно.
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0set_keys.ps1"
pause
