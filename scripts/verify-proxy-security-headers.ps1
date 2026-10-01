$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '../tools/verify/proxy_security_headers/verify-proxy-security-headers.ps1') @args
if ($LASTEXITCODE) { exit $LASTEXITCODE }
