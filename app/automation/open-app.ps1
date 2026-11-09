# Abre o app e navega para a tela de notificações via intent.
$ErrorActionPreference = "Stop"
$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$adb = Join-Path $sdk "platform-tools\adb.exe"
$package = "com.ricardogengcomp.conexa"

Write-Output "--- Abrindo app ---"
& $adb shell am start -n "$package/.package.ConexaApp" 2>&1 | ForEach-Object { Write-Host $_ }
Start-Sleep -Seconds 3

Write-Output "--- App aberto ---"
