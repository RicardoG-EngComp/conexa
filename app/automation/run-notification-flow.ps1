# Orquestra o fluxo completo de notificações no emulador:
# 1. Instala APK
# 2. Concede permissão de notificação
# 3. Abre o app
# 4. Injeta notificação de teste via RPC
# 5. Aguarda push chegar
# 6. Captura screenshot
param(
    [string]$ApkPath = "build\app\outputs\flutter-apk\app-release.apk",
    [string]$TestEmail = "",
    [string]$TestPassword = ""
)

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$adb = Join-Path $sdk "platform-tools\adb.exe"
$package = "com.ricardogengcomp.conexa"
$supabaseUrl = $env:SUPABASE_URL
$supabaseKey = $env:SUPABASE_ANON_KEY
$email = if ($TestEmail) { $TestEmail } else { $env:TEST_USER_A_EMAIL }
$password = if ($TestPassword) { $TestPassword } else { $env:TEST_USER_A_PASSWORD }

Write-Output "=============================================="
Write-Output "   Fluxo de teste de notificacoes - Conexa"
Write-Output "=============================================="

# 1. Instalar APK
Write-Output "`n[1/6] Instalando APK..."
& (Join-Path $scriptDir "install-apk.ps1") -ApkPath $ApkPath

# 2. Conceder permissão
Write-Output "`n[2/6] Concedendo permissão de notificações..."
& (Join-Path $scriptDir "grant-revoke-notification-permission.ps1") -Action "Grant"

# 3. Abrir o app
Write-Output "`n[3/6] Abrindo o app..."
& $adb shell am start -n "$package" 2>&1 | ForEach-Object { Write-Host $_ }
Start-Sleep -Seconds 5

# 4. Injetar notificação de teste
Write-Output "`n[4/6] Injetando notificação de teste via RPC..."
if ($supabaseUrl -and $supabaseKey -and $email -and $password) {
    Write-Output "  Logando conta de teste no Supabase..."
    $headers = @{
        "apikey"        = $supabaseKey
        "Content-Type"  = "application/json"
    }
    $loginBody = @{ email = $email; password = $password } | ConvertTo-Json
    $loginRes = Invoke-RestMethod -Uri "$supabaseUrl/auth/v1/token?grant_type=password" -Method Post -Headers $headers -Body $loginBody
    $authToken = $loginRes.access_token

    $notifHeaders = @{
        "apikey"       = $supabaseKey
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $authToken"
    }

    $userId = Invoke-RestMethod -Uri "$supabaseUrl/auth/v1/user" -Method Get -Headers $notifHeaders
    $userId = $userId.id

    $notifBody = @{
        p_user_id = $userId
        p_type    = "message"
        p_title   = "Teste automatizado"
        p_body    = "Push de teste automatizado"
    } | ConvertTo-Json

    $rpcUrl = "$supabaseUrl/rest/v1/rpc/enqueue_notification"
    $rpcRes = Invoke-RestMethod -Uri $rpcUrl -Method Post -Headers $notifHeaders -Body $notifBody
    Write-Output "  Notificação injetada. ID: $rpcRes"
} else {
    Write-Output "  AVISO: Credenciais não configuradas. Push não injetado."
}

# 5. Aguardar push chegar
Write-Output "`n[5/6] Aguardando push (10 segundos)..."
Start-Sleep -Seconds 10

# 6. Capturar screenshot como evidência
Write-Output "`n[6/6] Capturando screenshot..."
& (Join-Path $scriptDir "capture-screenshot.ps1") -OutputPath "notification-flow-$(Get-Date -Format 'yyyyMMdd-HHmmss').png"

Write-Output "`n=== Fluxo concluído. Verifique evidências visuais no arquivo PNG. ==="
