# Run from an elevated PowerShell:
#   cd server
#   powershell -ExecutionPolicy Bypass -File .\install\install-service.ps1
# The task starts the API at logon of the machine (SYSTEM) and restarts it if it dies.

$ErrorActionPreference = "Stop"
$Server = Split-Path -Parent $PSScriptRoot
Set-Location $Server

function New-ApiKey {
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return (($bytes | ForEach-Object { $_.ToString("x2") }) -join "")
}

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Error "Python 3.11+ is not on PATH. Install it from python.org and enable 'Add python.exe to PATH'."
}

& python -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Need Python 3.11 or newer."
}

if (-not (Test-Path ".\.venv\Scripts\python.exe")) {
    & python -m venv .venv
}
& .\.venv\Scripts\python.exe -m pip install --upgrade pip
& .\.venv\Scripts\python.exe -m pip install -r requirements.txt

$envFile = Join-Path $Server ".env"
if (-not (Test-Path $envFile)) {
    $ios = New-ApiKey
    $bot = New-ApiKey
    @"
DISCIPLINA_IOS_API_KEY=$ios
DISCIPLINA_BOT_API_KEY=$bot
DISCIPLINA_DB_PATH=./data/disciplina.db
DISCIPLINA_HOST=127.0.0.1
DISCIPLINA_PORT=8741
"@ | Set-Content -Path $envFile -Encoding utf8
    Write-Host "Wrote $envFile"
    Write-Host "iOS key and bot key are in that file. Copy the iOS key into the phone."
} else {
    Write-Host ".env already exists, keys were left unchanged."
}

& .\.venv\Scripts\python.exe -m app.seed
if ($LASTEXITCODE -ne 0) {
    Write-Error "Seed failed."
}

$pythonExe = Join-Path $Server ".venv\Scripts\python.exe"
$action = New-ScheduledTaskAction -Execute $pythonExe -Argument "-m app" -WorkingDirectory $Server
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 999 `
    -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask `
    -TaskName "DisciplinaServer" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -User "SYSTEM" `
    -RunLevel Highest `
    -Force | Out-Null
Start-ScheduledTask -TaskName "DisciplinaServer"
Write-Host "Service task DisciplinaServer is registered and started."
Write-Host "Monolith: http://127.0.0.1:8741/"
Write-Host "API: http://127.0.0.1:8741/health"
Write-Host "Docs: http://127.0.0.1:8741/docs"
Write-Host "Next: tailscale serve, then Add to Home Screen in Safari. Do not open port 8741 on the public firewall."
