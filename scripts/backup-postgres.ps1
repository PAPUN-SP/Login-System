param(
    [string]$ComposeFile = "docker-compose.prod.yml",
    [string]$EnvFile = ".env.prod"
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $PSScriptRoot
Set-Location $scriptRoot

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFile = "backups\logindb-$timestamp.sql"

if (-not (Test-Path $EnvFile)) { throw "Missing $EnvFile" }
New-Item -ItemType Directory -Force -Path backups | Out-Null

$dump = docker compose --env-file $EnvFile -f $ComposeFile exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
if ($LASTEXITCODE -ne 0) {
    throw "Database backup failed"
}
[System.IO.File]::WriteAllText($backupFile, ($dump -join [Environment]::NewLine), (New-Object System.Text.UTF8Encoding($false)) )

$storageUri = $env:BACKUP_S3_URI
if ($storageUri) {
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "BACKUP_S3_URI is set but AWS CLI is unavailable"
    }
    aws s3 cp $backupFile "$storageUri/$(Split-Path $backupFile -Leaf)"
    if ($LASTEXITCODE -ne 0) { throw "Object-storage upload failed" }
    Write-Output "Uploaded backup to configured object storage"
}

Get-ChildItem backups -Filter "*.sql" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
    Remove-Item -Force

Write-Output "Created $backupFile"
