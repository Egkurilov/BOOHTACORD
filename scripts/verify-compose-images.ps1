$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    $resolved = docker compose --env-file .env.example -f compose.yaml --profile operator config --format json
    if ($LASTEXITCODE -ne 0) {
        throw 'Compose image configuration is invalid.'
    }
    $compose = ($resolved -join "`n") | ConvertFrom-Json
    $expected = [ordered]@{
        api = 'voice-platform-api:dev'
        migrate = 'voice-platform-api:dev'
        'bootstrap-admin' = 'voice-platform-api:dev'
        'recover-admin' = 'voice-platform-api:dev'
        web = 'voice-platform-web:dev'
    }
    foreach ($service in $expected.Keys) {
        $actual = $compose.services.PSObject.Properties[$service].Value.image
        if ([string]::IsNullOrWhiteSpace($actual)) {
            throw "Service $service has no explicit image reference."
        }
        if ($actual -match ':latest$') {
            throw "Service $service must not resolve to a latest image."
        }
        if ($actual -ne $expected[$service]) {
            throw "Service $service image is $actual, expected $($expected[$service])."
        }
    }
} finally {
    Pop-Location
}
