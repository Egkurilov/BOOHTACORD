$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '../tools/verify/compose_log_rotation/verify-compose-log-rotation.ps1') @args
if ($LASTEXITCODE) { exit $LASTEXITCODE }
