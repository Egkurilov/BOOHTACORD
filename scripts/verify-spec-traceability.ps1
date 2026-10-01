$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '../tools/verify/spec_traceability/verify-spec-traceability.ps1') @args
if ($LASTEXITCODE) { exit $LASTEXITCODE }
