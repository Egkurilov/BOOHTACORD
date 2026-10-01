$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '../tools/verify/poc_01_evidence/verify-poc-01-evidence.test.ps1') @args
if ($LASTEXITCODE) { exit $LASTEXITCODE }
