# === Загрузка API-ключей студии ===
# Сохраняет ключи в переменные окружения (User, постоянно). Ключи в файле НЕ хранятся.
$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "=== API-ключи AI Game Studio ===" -ForegroundColor Cyan
Write-Host "Ключи сохранятся постоянно (переменные окружения пользователя)."
Write-Host "Enter без ввода — оставить текущий ключ." -ForegroundColor DarkGray
Write-Host ""

function Set-ApiKey($name, $label) {
    $cur = [Environment]::GetEnvironmentVariable($name, "User")
    if ($cur) {
        $mask = $cur.Substring(0, [Math]::Min(8, $cur.Length)) + "..." + $cur.Length + " симв."
        Write-Host "$label" -ForegroundColor White
        Write-Host "  $name сейчас: $mask" -ForegroundColor Green
    } else {
        Write-Host "$label" -ForegroundColor White
        Write-Host "  $name сейчас: НЕ задан" -ForegroundColor Red
    }
    $ans = Read-Host "  Вставь ключ (или Enter — не менять)"
    if (-not [string]::IsNullOrWhiteSpace($ans)) {
        [Environment]::SetEnvironmentVariable($name, $ans.Trim(), "User")
        Write-Host "  -> сохранён." -ForegroundColor Yellow
    } else {
        Write-Host "  -> оставлен как есть." -ForegroundColor DarkGray
    }
    Write-Host ""
}

Set-ApiKey "OPENAI_API_KEY"    "OpenAI  — текст (gpt-4.1) + фото (gpt-image-1)"
Set-ApiKey "ANTHROPIC_API_KEY" "Claude  — код (Fable 5)"

Write-Host "Готово." -ForegroundColor Cyan
Write-Host "ВАЖНО: закрой и открой заново терминал / Claude Code, чтобы новые ключи подхватились." -ForegroundColor Yellow
