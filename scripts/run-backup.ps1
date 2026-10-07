$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$backupEnv = Join-Path $root '.backup.env'
if (Test-Path $backupEnv) {
    Get-Content $backupEnv | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), 'Process')
        }
    }
}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\backup-postgres.ps1') -EnvFile '.env.prod'
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
