# Instala APK release no emulador/dispositivo via adb.
param(
    [string]$ApkPath = "build\app\outputs\flutter-apk\app-release.apk"
)

$ErrorActionPreference = "Stop"
$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$adb = Join-Path $sdk "platform-tools\adb.exe"
$fullPath = Join-Path (Get-Location) $ApkPath

if (-not (Test-Path $fullPath)) {
    Write-Error "APK nao encontrado em: $fullPath"
    Write-Output "Use --build-name/--build-number para gerar o APK primeiro."
    exit 1
}

Write-Output "--- Instalando APK: $fullPath ---"
& $adb install -r $fullPath 2>&1 | ForEach-Object { Write-Host $_ }

Write-Output "--- APK instalado ---"
