$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '../tools/verify/github_workflows/verify-github-workflows.ps1') @args
if ($LASTEXITCODE) { exit $LASTEXITCODE }
