$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '../tools/verify/contracts/verify-contracts.ps1') @args
if ($LASTEXITCODE) { exit $LASTEXITCODE }
