@echo off
REM === Автономная ночь: ОДНА игра С КОДОМ. Самолечение, без подтверждений, утром — отчёт ===
chcp 65001 >nul
set PYTHONUTF8=1
set PYTHONIOENCODING=utf-8
set PYTHONUNBUFFERED=1
set WITH_CODE=1
set "PYTHONPATH=%~dp0..\.."
cd /d "%~dp0..\.."
python -m ai_game_studio.night.night_auto
echo.
echo === Готово. Утренний отчёт: ai_game_studio\УТРЕННИЙ_ОТЧЁТ.md ===
pause
