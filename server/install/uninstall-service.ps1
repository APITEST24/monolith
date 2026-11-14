# Elevated PowerShell:
#   powershell -ExecutionPolicy Bypass -File .\install\uninstall-service.ps1

$ErrorActionPreference = "Stop"
Unregister-ScheduledTask -TaskName "DisciplinaServer" -Confirm:$false
Write-Host "Scheduled task DisciplinaServer removed. The database file was left in place."
