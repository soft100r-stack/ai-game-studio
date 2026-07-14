# === ГЛУБОКАЯ НОЧЬ: ОДНА игра, максимум качества ===
# Модель qwen2.5:7b (качественнее), глубокий проход (редактор+плейтест), 2 раунда критика.
# Фаза 1: детальный ДИЗАЙН. Фаза 2: КОД (черновой), если остаётся время.
# Утром лучший код — через OpenAI: --code-only.
$ErrorActionPreference = "Continue"

# --- ОДНА игра (меняй под себя). Жанр 'any' = студия сама придумает механику под идею ---
$Game = @{ id = "night_crazy_01"; genre = "any"; theme = "Гриб-детектив в подземном неоновом городе спор расследует кражу чужих снов. Улики он выращивает как светящийся мицелий по ритму биолюминесцентного джаза, а подозреваемых допрашивает, играя с ними в игру теней. Каждая раскрытая тайна освещает ещё один тёмный туннель грибницы." }

# --- Настройки качества ---
$Model = "qwen2.5:7b"            # ДИЗАЙН: креативная модель
$CodeModel = "qwen2.5-coder:7b"  # КОД: специальная coder-модель (пишет рабочий код)
$Levels = 20
$MaxHours = 14                   # времени не жалеем — пусть работает долго, но качественно
$Ollama = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"

# --- Окружение: включаем глубокий проход и лишний раунд критика ---
$env:DEEP = "1"                  # редактор (углубление) + плейтест (баланс)
$env:MAX_REVISION_ROUNDS = "2"   # критик проходит дважды
$env:OLLAMA_MODEL = $Model             # дизайн
$env:OLLAMA_CODE_MODEL = $CodeModel    # код (coder-модель)
$env:OLLAMA_NUM_CTX = "4096"           # держим RAM в узде (у тебя 8 ГБ)
$env:OLLAMA_TIMEOUT = "3600"           # до 60 мин на вызов (код на CPU долгий)
$env:PYTHONUTF8 = "1"
$env:PYTHONUNBUFFERED = "1"
$env:STUDIO_GENRE = $Game.genre

Set-Location $PSScriptRoot
New-Item -ItemType Directory -Force -Path "night_logs" | Out-Null
$start = Get-Date
$deadline = $start.AddHours($MaxHours)

# --- Ollama: сервер + модель ---
$up = $false
try { Invoke-RestMethod "http://localhost:11434/api/tags" -TimeoutSec 4 | Out-Null; $up = $true } catch {}
if (-not $up) { Write-Host "Запускаю Ollama..." -ForegroundColor Yellow; Start-Process -FilePath $Ollama -ArgumentList "serve" -WindowStyle Hidden; Start-Sleep 6 }
& $Ollama pull $Model | Out-Null
& $Ollama pull $CodeModel | Out-Null

# --- ФАЗА 1: ДЕТАЛЬНЫЙ ДИЗАЙН ---
Write-Host "`n########## ФАЗА 1: ГЛУБОКИЙ ДИЗАЙН ($($Game.id)) ##########" -ForegroundColor Magenta
$t = Get-Date
$a = @("-m","ai_game_studio.main","--engine","ollama","--skip-code",
       "--game",$Game.id,"--genre",$Game.genre,"--levels","$Levels","--theme",$Game.theme)
python @a *> "night_logs\$($Game.id)_design.log"
$m = [math]::Round(((Get-Date)-$t).TotalMinutes,1)
$designOk = Test-Path "games\$($Game.id)\design\game_design_document.json"
if ($designOk) { Write-Host "  ДИЗАЙН OK ($m мин) -> games\$($Game.id)\design\" -ForegroundColor Green }
else { Write-Host "  дизайн НЕ дошёл ($m мин) — см. лог" -ForegroundColor Red }

# --- ФАЗА 2: КОД, если успеваем ---
if ($designOk -and ((Get-Date) -lt $deadline)) {
    Write-Host "`n########## ФАЗА 2: КОД (черновой, локально) ##########" -ForegroundColor Magenta
    $t = Get-Date
    python -m ai_game_studio.main --engine ollama --game $Game.id --genre $Game.genre --code-only *> "night_logs\$($Game.id)_code.log"
    $m = [math]::Round(((Get-Date)-$t).TotalMinutes,1)
    if (Test-Path "games\$($Game.id)\source\godot_project\project.godot") { Write-Host "  код OK ($m мин, черновой)" -ForegroundColor Green }
    else { Write-Host "  код НЕ дошёл ($m мин)" -ForegroundColor Red }
} else { Write-Host "Код пропущен (нет дизайна или дедлайн)." -ForegroundColor Yellow }

$total = [math]::Round(((Get-Date)-$start).TotalMinutes,1)
Write-Host "`n=== ГОТОВО за $total мин. Дизайн: games\$($Game.id)\design\ ===" -ForegroundColor Green
Write-Host "Качественный код утром: python -m ai_game_studio.main --engine openai --game $($Game.id) --genre $($Game.genre) --code-only"
