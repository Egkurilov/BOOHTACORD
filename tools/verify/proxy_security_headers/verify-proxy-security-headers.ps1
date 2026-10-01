$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$caddyfile = Get-Content -LiteralPath (Join-Path $projectRoot 'docker/Caddyfile') -Raw

foreach ($line in @(
    'X-Content-Type-Options "nosniff"',
    'X-Frame-Options "SAMEORIGIN"',
    'Referrer-Policy "no-referrer"',
    'Permissions-Policy "camera=(), geolocation=(), payment=(), usb=()"'
)) {
    if ($caddyfile -notmatch [regex]::Escape($line)) {
        throw "Missing proxy header: $line"
    }
}

foreach ($boundary in @(
    'forward_auth api:8080',
    'respond @private_metrics "Not Found" 404'
)) {
    if ($caddyfile -notmatch [regex]::Escape($boundary)) {
        throw "Missing proxy boundary: $boundary"
    }
}

Write-Output 'Proxy security headers contract: OK'
