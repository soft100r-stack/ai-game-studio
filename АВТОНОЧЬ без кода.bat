@echo off
REM === Автономная ночь: ТОЛЬКО ДИЗАЙН одной игры (без кода). Код сделаешь утром через OpenAI. ===
chcp 65001 >nul
set PYTHONUTF8=1
set PYTHONIOENCODING=utf-8
set PYTHONUNBUFFERED=1
set WITH_CODE=0
set "PYTHONPATH=%~dp0.."
cd /d "%~dp0.."
python -m ai_game_studio.night.night_auto
echo.
echo === Готово (только дизайн). Отчёт: ai_game_studio\УТРЕННИЙ_ОТЧЁТ.md ===
pause
