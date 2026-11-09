# Captura screenshot do emulador.
param(
    [string]$OutputPath = "screenshot-$(Get-Date -Format 'yyyyMMdd-HHmmss').png"
)

$ErrorActionPreference = "Stop"
$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$adb = Join-Path $sdk "platform-tools\adb.exe"

Write-Output "--- Screenshot -> $OutputPath ---"
& $adb exec-out "screencap -p" > $OutputPath
Write-Output "Screenshot salvo em: $OutputPath"
