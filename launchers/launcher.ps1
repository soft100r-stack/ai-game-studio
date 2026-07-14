# Универсальная запускалка игр студии.
# Показывает все собранные игры, даёт выбрать и запускает выбранную в Godot 4.
$ErrorActionPreference = "Stop"
$godot = "C:\Users\POLLAP\Godot\Godot_v4.3-stable_win64.exe"
# launcher лежит в launchers/, игры — на уровень выше (в корне пакета)
$root  = Join-Path (Split-Path $PSScriptRoot -Parent) "games"

if (-not (Test-Path $godot)) { Write-Host "Godot не найден: $godot"; Read-Host "Enter для выхода"; exit }
if (-not (Test-Path $root))  { Write-Host "Папки games нет — игр пока не создано."; Read-Host "Enter"; exit }

$games = Get-ChildItem $root -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName "source\godot_project\project.godot") } |
    Sort-Object Name
if ($games.Count -eq 0) { Write-Host "Готовых игр (с кодом) пока нет."; Read-Host "Enter"; exit }

Write-Host ""
Write-Host "=== ИГРЫ СТУДИИ ===" -ForegroundColor Cyan
for ($i = 0; $i -lt $games.Count; $i++) {
    $proj = Join-Path $games[$i].FullName "source\godot_project\project.godot"
    $name = ""
    try { $name = ([regex]'config/name="(.+?)"').Match((Get-Content $proj -Raw -Encoding UTF8)).Groups[1].Value } catch {}
    Write-Host ("  [{0}] {1}   {2}" -f ($i + 1), $games[$i].Name, $name)
}
Write-Host ""
$choice = Read-Host "Введи номер игры и нажми Enter"
$idx = 0
if (-not [int]::TryParse($choice, [ref]$idx) -or $idx -lt 1 -or $idx -gt $games.Count) {
    Write-Host "Неверный номер."; Read-Host "Enter"; exit
}
$proj = Join-Path $games[$idx - 1].FullName "source\godot_project"

Write-Host "Готовлю проект (импорт ресурсов)..." -ForegroundColor Yellow
& $godot --headless --path $proj --import 2>$null | Out-Null
Write-Host "Запускаю игру..." -ForegroundColor Green
& $godot --path $proj
