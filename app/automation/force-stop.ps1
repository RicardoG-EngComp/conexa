# Força parada do app.
$ErrorActionPreference = "Stop"
$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$adb = Join-Path $sdk "platform-tools\adb.exe"
$package = "com.ricardogengcomp.conexa"

Write-Output "--- Force-stop $package ---"
& $adb shell am force-stop $package
Write-Output "App parado."
