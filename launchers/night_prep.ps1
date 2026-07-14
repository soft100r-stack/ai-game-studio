# === НОЧНАЯ ПОДГОТОВКА ===
# Фаза 1: гарантированно генерит ДИЗАЙН всех игр (надёжно).
# Фаза 2: если остаётся время до дедлайна — дописывает КОД локально (черновой, 3B на CPU).
# Утром лучший код всё равно получишь через OpenAI: --code-only.
$ErrorActionPreference = "Continue"

# --- Настройки ---
$Model = "llama3.2"           # лёгкая модель под 8 ГБ RAM
$Levels = 10
$MaxHours = 9                 # жёсткий дедлайн: после него новые тяжёлые шаги не стартуют
$DoCodeIfTime = $true         # писать ли код, если есть время
$Ollama = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"

# --- СПИСОК ИГР (добавляй/меняй свои идеи) ---
$Games = @(
  @{ id = "night_rogue_library";   genre = "roguelike"; theme = "Глубоководная библиотека: затонувший архив, кристаллы знаний, опасные течения" },
  @{ id = "night_match_library";   genre = "match3";    theme = "Глубоководная библиотека: биолюминесцентные кристаллы знаний" },
  @{ id = "night_rogue_clockwork"; genre = "roguelike"; theme = "Часовой механизм умирающего города: шестерни, пар, время утекает" },
  @{ id = "night_match_spores";    genre = "match3";    theme = "Подземное царство светящихся грибов и спор" },
  @{ id = "night_rogue_free";      genre = "roguelike"; theme = "" },
  @{ id = "night_match_free";      genre = "match3";    theme = "" }
)

# --- Окружение (экономим RAM, щедрый таймаут) ---
$env:STUDIO_GENRE = ""
$env:OLLAMA_MODEL = $Model
$env:OLLAMA_NUM_CTX = "4096"
$env:OLLAMA_TIMEOUT = "1800"
$env:MAX_REVISION_ROUNDS = "1"
$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"
$env:PYTHONUNBUFFERED = "1"
$pkg = Split-Path $PSScriptRoot -Parent               # корень пакета (launchers/ лежит в нём)
$env:PYTHONPATH = (Split-Path $pkg -Parent)           # внешняя папка для `-m ai_game_studio.main`

Set-Location $pkg
New-Item -ItemType Directory -Force -Path "night_logs" | Out-Null
$start = Get-Date
$deadline = $start.AddHours($MaxHours)

# --- Ollama: сервер + модель ---
$up = $false
try { Invoke-RestMethod "http://localhost:11434/api/tags" -TimeoutSec 4 | Out-Null; $up = $true } catch {}
if (-not $up) { Write-Host "Запускаю Ollama..." -ForegroundColor Yellow; Start-Process -FilePath $Ollama -ArgumentList "serve" -WindowStyle Hidden; Start-Sleep 6 }
& $Ollama pull $Model | Out-Null

# --- ФАЗА 1: ДИЗАЙН всех игр ---
Write-Host "`n########## ФАЗА 1: ДИЗАЙН ##########" -ForegroundColor Magenta
foreach ($g in $Games) {
    Write-Host "`n=== [дизайн] $($g.id) [$($g.genre)] ===" -ForegroundColor Cyan
    $t = Get-Date
    $a = @("-m","ai_game_studio.main","--engine","ollama","--skip-code","--game",$g.id,"--genre",$g.genre,"--levels","$Levels")
    if ($g.theme) { $a += @("--theme",$g.theme) }
    python @a *> "night_logs\$($g.id)_design.log"
    $m = [math]::Round(((Get-Date)-$t).TotalMinutes,1)
    if (Test-Path "games\$($g.id)\design\game_design_document.json") { Write-Host "  дизайн OK ($m мин)" -ForegroundColor Green }
    else { Write-Host "  дизайн НЕ ДОШЁЛ ($m мин)" -ForegroundColor Red }
}

# --- ФАЗА 2: КОД, пока есть время до дедлайна ---
if ($DoCodeIfTime) {
    Write-Host "`n########## ФАЗА 2: КОД (если есть время) ##########" -ForegroundColor Magenta
    foreach ($g in $Games) {
        if ((Get-Date) -ge $deadline) { Write-Host "Дедлайн — код дальше не пишу." -ForegroundColor Yellow; break }
        if (-not (Test-Path "games\$($g.id)\design\game_design_document.json")) { continue }
        Write-Host "`n=== [код] $($g.id) ===" -ForegroundColor Cyan
        $t = Get-Date
        python -m ai_game_studio.main --engine ollama --game $g.id --genre $g.genre --code-only *> "night_logs\$($g.id)_code.log"
        $m = [math]::Round(((Get-Date)-$t).TotalMinutes,1)
        if (Test-Path "games\$($g.id)\source\godot_project\project.godot") { Write-Host "  код OK ($m мин, черновой)" -ForegroundColor Green }
        else { Write-Host "  код НЕ ДОШЁЛ ($m мин)" -ForegroundColor Red }
    }
}

$total = [math]::Round(((Get-Date)-$start).TotalMinutes,1)
Write-Host "`n=== ГОТОВО за $total мин. Дизайн: games\night_*\design\ ===" -ForegroundColor Green
Write-Host "Качественный код утром: python -m ai_game_studio.main --engine openai --game <id> --code-only"
