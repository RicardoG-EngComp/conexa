# Inicia o emulador Android em modo headless.
# Uso: powershell -File start-emulator.ps1 [-AvdName "Conexa_Pixel_API_35"]
param(
    [string]$AvdName = "Conexa_Pixel_API_35"
)

$ErrorActionPreference = "Stop"
$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$emulator = Join-Path $sdk "emulator\emulator.exe"
$adb = Join-Path $sdk "platform-tools\adb.exe"

if (-not (Test-Path $emulator)) {
    Write-Error "emulator nao encontrado em: $emulator"
    exit 1
}

Write-Output "--- Verificando se emulador ja esta rodando ---"
$alreadyRunning = & $adb devices 2>&1 | Select-String "emulator-" | Select-String "device"
if ($alreadyRunning) {
    Write-Output "Emulador já rodando. Prosseguindo."
    exit 0
}

Write-Output "--- Iniciando emulador '$AvdName' (headless) ---"
$process = Start-Process -FilePath $emulator -ArgumentList @(
    "-avd", $AvdName,
    "-no-window",
    "-no-audio",
    "-no-boot-anim",
    "-gpu", "swiftshader_indirect"
) -PassThru -WindowStyle Hidden

Write-Output "Processo emulador PID: $($process.Id)"

# Aguardar boot completo
Write-Output "Aguardando boot..."
$timeout = 300
$elapsed = 0
while ($elapsed -lt $timeout) {
    $bootComplete = & $adb shell getprop sys.boot_completed 2>&1
    if ("$bootComplete" -match "1") {
        Write-Output "Boot completo após $elapsed segundos."
        break
    }
    Start-Sleep -Seconds 5
    $elapsed += 5
    Write-Host "  ... $elapsed / $timeout segundos"
}

if ($elapsed -ge $timeout) {
    Write-Error "Timeout de boot após $timeout segundos."
    exit 1
}

Write-Output "--- Emulador com boot completo ---"
& $adb devices 2>&1 | ForEach-Object { Write-Host $_ }
