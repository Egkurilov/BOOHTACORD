$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '../tools/verify/otel_egress/verify-otel-egress.ps1') @args
if ($LASTEXITCODE) { exit $LASTEXITCODE }
