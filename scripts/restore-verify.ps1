param(
    [string]$ComposeFile = "docker-compose.prod.yml",
    [string]$EnvFile = ".env.prod",
    [string]$BackupFile = ""
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $PSScriptRoot
Set-Location $scriptRoot
if (-not $BackupFile) {
    $BackupFile = (Get-ChildItem backups -Filter '*.sql' | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
if (-not $BackupFile -or -not (Test-Path $BackupFile)) { throw "No SQL backup found" }

$restoreDb = "restore_verify"
$dbUser = (Get-Content $EnvFile | Where-Object { $_ -match '^DB_USERNAME=' } | ForEach-Object { $_.Substring(12) })
if (-not $dbUser) { throw "DB_USERNAME is missing" }

docker compose --env-file $EnvFile -f $ComposeFile exec -T postgres sh -c "dropdb --if-exists -U '$dbUser' '$restoreDb'"
if ($LASTEXITCODE -ne 0) { throw "Could not remove old restore database" }
docker compose --env-file $EnvFile -f $ComposeFile exec -T postgres sh -c "createdb -U '$dbUser' '$restoreDb'"
if ($LASTEXITCODE -ne 0) { throw "Could not create isolated restore database" }

$dump = Get-Content -Raw -Encoding UTF8 $BackupFile
$dump | docker compose --env-file $EnvFile -f $ComposeFile exec -T postgres sh -c "psql -v ON_ERROR_STOP=1 -U '$dbUser' -d '$restoreDb'"
if ($LASTEXITCODE -ne 0) { throw "Backup restore failed" }

$sql = "select count(*) from information_schema.tables where table_schema = chr(112)||chr(117)||chr(98)||chr(108)||chr(105)||chr(99);"
$count = docker compose --env-file $EnvFile -f $ComposeFile exec -T postgres sh -c "psql -At -U '$dbUser' -d '$restoreDb' -c '$sql'"
Write-Output "Restored $BackupFile into $restoreDb; public table count: $count"
