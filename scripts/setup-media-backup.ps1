# Conexa - configura credenciais do backup de midia no R2 e o segredo do cron.
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-media-backup.ps1
# Nao coloque valores no arquivo; o script pergunta no terminal.

$ErrorActionPreference = "Stop"

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
  throw "Node.js/npx nao encontrado. Instale o Node.js LTS e tente de novo."
}

$projectRef = "lgsyuusotabxrjqgyqdq"
$backupBucket = "conexa-backup"

Write-Host ""
Write-Host "=== Conexa: backup de midia ===" -ForegroundColor Cyan
Write-Host "Use um token R2 com Object Read & Write nos buckets:"
Write-Host "  conexa-profile, conexa-study e conexa-backup"
Write-Host ""

$accessKey = (Read-Host "R2 Backup Access Key ID").Trim()
$secretSecure = Read-Host "R2 Backup Secret Access Key" -AsSecureString

$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretSecure)
try {
  $secretKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
}

if ([string]::IsNullOrWhiteSpace($accessKey) -or [string]::IsNullOrWhiteSpace($secretKey)) {
  throw "Access Key ID e Secret Access Key do backup sao obrigatorios."
}

$bytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$backupSecret = -join ($bytes | ForEach-Object { $_.ToString("x2") })

$tempFile = Join-Path $env:TEMP ("conexa-backup-" + [guid]::NewGuid().ToString("N") + ".env")

$lines = @(
  "R2_BACKUP_ACCESS_KEY_ID=$accessKey",
  "R2_BACKUP_SECRET_ACCESS_KEY=$secretKey",
  "R2_BUCKET_BACKUP=$backupBucket",
  "MEDIA_BACKUP_SECRET=$backupSecret"
)

try {
  [System.IO.File]::WriteAllLines($tempFile, $lines, [System.Text.Encoding]::ASCII)

  Write-Host ""
  Write-Host "Gravando secrets no Supabase ($projectRef)..." -ForegroundColor Yellow

  npx -y supabase@latest secrets set --env-file $tempFile --remote=$projectRef --yes

  if ($LASTEXITCODE -ne 0) {
    throw "Falha ao gravar. Rode 'npx -y supabase@latest login' e tente de novo."
  }

  if (Get-Command gh -ErrorAction SilentlyContinue) {
    Write-Host "Atualizando MEDIA_BACKUP_SECRET no GitHub..." -ForegroundColor Yellow
    gh secret set MEDIA_BACKUP_SECRET --body $backupSecret
    if ($LASTEXITCODE -ne 0) {
      throw "Falha ao gravar MEDIA_BACKUP_SECRET no GitHub. Adicione manualmente."
    }
  } else {
    Write-Host ""
    Write-Host "gh CLI nao encontrado. Adicione MEDIA_BACKUP_SECRET manualmente no GitHub." -ForegroundColor Yellow
    Write-Host "O valor foi gerado, mas nao sera exibido aqui por seguranca." -ForegroundColor Yellow
  }

  Write-Host ""
  Write-Host "OK. Backup configurado." -ForegroundColor Green
  Write-Host "Agende/rode o workflow media-backup no GitHub Actions." -ForegroundColor Cyan
}
finally {
  Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
  Remove-Variable secretKey, secretSecure, accessKey, backupSecret, bytes -ErrorAction SilentlyContinue
  [GC]::Collect()
}
