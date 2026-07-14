@echo off
REM Двойной клик запускает игру в Godot 4.
set "GODOT=C:\Users\POLLAP\Godot\Godot_v4.3-stable_win64.exe"
"%GODOT%" --headless --path "%~dp0source\godot_project" --import
"%GODOT%" --path "%~dp0source\godot_project"
