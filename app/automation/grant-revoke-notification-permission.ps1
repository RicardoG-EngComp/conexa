# Concede ou revoga a permissão de notificações no emulador.
# Uso: powershell -File grant-revoke-notification-permission.ps1 [-Action Grant|Revoke]
param(
    [ValidateSet("Grant", "Revoke")]
    [string]$Action = "Grant"
)

$ErrorActionPreference = "Stop"
$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$adb = Join-Path $sdk "platform-tools\adb.exe"
$package = "com.ricardogengcomp.conexa"

switch ($Action) {
    "Grant" {
        Write-Output "--- Concedendo permissão de notificação ---"
        & $adb shell pm grant $package "android.permission.POST_NOTIFICATIONS"
        Write-Output "Permissão concedida."
    }
    "Revoke" {
        Write-Output "--- Revogando permissão de notificação ---"
        & $adb shell pm revoke $package "android.permission.POST_NOTIFICATIONS"
        Write-Output "Permissão revogada."
    }
}
