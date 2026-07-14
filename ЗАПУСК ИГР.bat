@echo off
REM Двойной клик — список всех игр студии, выбираешь номер, игра запускается.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0launcher.ps1"
pause
