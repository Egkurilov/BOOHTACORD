$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '../tools/verify/compose_images/verify-compose-images.ps1') @args
if ($LASTEXITCODE) { exit $LASTEXITCODE }
