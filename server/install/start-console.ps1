# Foreground run, useful while checking the log. Ctrl+C stops it.
$ErrorActionPreference = "Stop"
$Server = Split-Path -Parent $PSScriptRoot
Set-Location $Server
& .\.venv\Scripts\python.exe -m app
