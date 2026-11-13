# Conexa - grava credenciais do R2 nos secrets do Supabase.
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-r2.ps1
# Nao coloque valores no arquivo; o script pergunta no terminal.

$ErrorActionPreference = "Stop"

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
  throw "Node.js/npx nao encontrado. Instale o Node.js LTS e tente de novo."
}

$projectRef = "lgsyuusotabxrjqgyqdq"
$profileBucket = "conexa-profile"
$studyBucket = "conexa-study"
$testBucket = "conexa-test"

Write-Host ""
Write-Host "=== Conexa: configurar R2 no Supabase ===" -ForegroundColor Cyan
Write-Host "Cole apenas o Account ID (32 caracteres), nao a URL do endpoint."
Write-Host ""

$accountId = (Read-Host "Cloudflare Account ID").Trim()
$accountId = $accountId -replace '^https?://', ''
$accountId = $accountId -replace '\.r2\.cloudflarestorage\.com.*$', ''
$accountId = $accountId.Trim('/').ToLowerInvariant()

if ($accountId -notmatch '^[0-9a-f]{32}$') {
  throw "Account ID invalido. Use apenas o ID de 32 caracteres, sem https:// e sem .r2.cloudflarestorage.com."
}

$accessKey = (Read-Host "R2 Access Key ID").Trim()
$secretSecure = Read-Host "R2 Secret Access Key" -AsSecureString

$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretSecure)
try {
  $secretKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
}

if ([string]::IsNullOrWhiteSpace($accessKey) -or [string]::IsNullOrWhiteSpace($secretKey)) {
  throw "Access Key ID e Secret Access Key sao obrigatorios."
}

# Se usar jurisdicao EU/US/FedRAMP, ajuste o endpoint abaixo.
$endpoint = "https://$accountId.r2.cloudflarestorage.com"
$tempFile = Join-Path $env:TEMP ("conexa-r2-" + [guid]::NewGuid().ToString("N") + ".env")

$lines = @(
  "R2_ACCOUNT_ID=$accountId",
  "R2_ACCESS_KEY_ID=$accessKey",
  "R2_SECRET_ACCESS_KEY=$secretKey",
  "R2_ENDPOINT=$endpoint",
  "R2_BUCKET_PROFILE=$profileBucket",
  "R2_BUCKET_STUDY=$studyBucket",
  "R2_BUCKET_TEST=$testBucket",
  "R2_BUCKET_BACKUP=conexa-backup",
  "MEDIA_BACKEND=r2"
)

try {
  [System.IO.File]::WriteAllLines($tempFile, $lines, [System.Text.Encoding]::ASCII)

  Write-Host ""
  Write-Host "Gravando secrets no Supabase ($projectRef)..." -ForegroundColor Yellow

  npx -y supabase@latest secrets set --env-file $tempFile --remote=$projectRef --yes

  if ($LASTEXITCODE -ne 0) {
    throw "Falha ao gravar. Rode 'npx -y supabase@latest login' e tente de novo."
  }

  Write-Host ""
  Write-Host "OK. Secrets gravados." -ForegroundColor Green
  npx -y supabase@latest secrets list --remote=$projectRef
}
finally {
  Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
  Remove-Variable secretKey, secretSecure, accessKey, accountId -ErrorAction SilentlyContinue
  [GC]::Collect()
}
