@echo off
REM Двойной клик перед сном — ОДНА игра, максимум качества (qwen2.5:7b + глубокий проход).
REM Для быстрой генерации многих игр разом используй вместо этого night_prep.ps1.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0night_deep.ps1"
echo.
echo Готово. Можно закрывать окно.
pause
