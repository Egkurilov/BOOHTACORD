$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '../tools/verify/ci_sbom/verify-ci-sbom.ps1') @args
if ($LASTEXITCODE) { exit $LASTEXITCODE }
