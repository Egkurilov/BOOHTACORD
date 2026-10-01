$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$composePath = Join-Path $projectRoot 'compose.yaml'
$compose = Get-Content -LiteralPath $composePath -Raw
$runtimeServices = @('postgres', 'livekit', 'api', 'web', 'proxy')

foreach ($service in $runtimeServices) {
    $escapedService = [regex]::Escape($service)
    $serviceBlock = [regex]::Match(
        $compose,
        "(?ms)^  ${escapedService}:\r?\n(?<body>.*?)(?=^  [a-z][a-z0-9-]*:\r?\n|^networks:)"
    )
    if (-not $serviceBlock.Success) {
        throw "Missing Compose service: $service"
    }
    if ($serviceBlock.Groups['body'].Value -notmatch '(?m)^    logging: \*json-log-rotation$') {
        throw "Service $service must use json-log-rotation."
    }
}

$rotation = [regex]::Match(
    $compose,
    '(?ms)^x-json-log-rotation: &json-log-rotation\r?\n  driver: json-file\r?\n  options:\r?\n    max-size: "10m"\r?\n    max-file: "3"$'
)
if (-not $rotation.Success) {
    throw 'Compose json-log-rotation must retain three 10 MiB JSON log files.'
}

Write-Output 'Compose log rotation contract: OK'
