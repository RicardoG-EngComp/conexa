# Cria AVD Android do zero via avdmanager.
# Nome: Conexa_Pixel_API_35
param(
    [string]$AvdName = "Conexa_Pixel_API_35",
    [string]$SystemImage = "system-images;android-35;google_apis;x86_64"
)

$ErrorActionPreference = "Stop"
$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$avdmanager = Join-Path $sdk "cmdline-tools\latest\bin\avdmanager.bat"
$sdkmanager = Join-Path $sdk "cmdline-tools\latest\bin\sdkmanager.bat"

if (-not (Test-Path $avdmanager)) {
    Write-Error "avdmanager nao encontrado em: $avdmanager"
    exit 1
}

Write-Output "--- Verificando system image ---"
$images = Get-ChildItem -Path (Join-Path $sdk "system-images") -ErrorAction SilentlyContinue
$hasImage = $images | Where-Object { $_.Name -match "android-35" }

if (-not $hasImage) {
    Write-Output "System image $SystemImage nao encontrada. Instalando..."
    & $sdkmanager $SystemImage --sdk_root=$sdk | ForEach-Object { Write-Host $_ }
} else {
    Write-Output "System image android-35 já disponível."
}

Write-Output "--- Criando AVD $AvdName ---"
$existing = & $avdmanager list avd --compact 2>&1 | Select-String "$AvdName"
if ($existing) {
    Write-Output "AVD '$AvdName' já existe. Deletando..."
    & $avdmanager delete avd --name $AvdName 2>&1 | Out-Null
}

$sysResponses = & $avdmanager list avd --compact 2>&1
$userProfile = Join-Path $env:USERPROFILE ".android"

$createArgs = @(
    "create", "avd", "--name", $AvdName,
    "--package", $SystemImage,
    "--device", "pixel_5",
    "--force"
)
& $avdmanager @createArgs --force 2>&1 | ForEach-Object { Write-Host $_ }

Write-Output "--- AVD criado: $AvdName ---"
& $avdmanager list avd 2>&1 | Select-String $AvdName | ForEach-Object { Write-Host $_ }
