$ErrorActionPreference = 'Stop'

$sourceSpecification = if ($env:VOICE_PLATFORM_APPROVED_SPEC_PATH) {
    $env:VOICE_PLATFORM_APPROVED_SPEC_PATH
} else {
    'C:\Users\egkur\Downloads\TZ_Voice_Platform_v1.0.md'
}
$backlogPath = Join-Path $PSScriptRoot '..\..\..\backlog\tasks.yaml'
$indexPath = Join-Path $PSScriptRoot '..\..\..\backlog\approved-requirements.json'

if (-not (Test-Path -LiteralPath $indexPath)) {
    throw "Approved requirement index is unavailable: $indexPath"
}

if (-not (Test-Path -LiteralPath $backlogPath)) {
    throw "Backlog is unavailable: $backlogPath"
}

$index = Get-Content -Raw -LiteralPath $indexPath | ConvertFrom-Json
$requirements = @($index.requirement_ids | Sort-Object -Unique)
if ($requirements.Count -ne 39 -or $requirements.Count -ne @($index.requirement_ids).Count) {
    throw 'Approved requirement index must contain 39 unique IDs.'
}
if ($env:VOICE_PLATFORM_APPROVED_SPEC_PATH -and -not (Test-Path -LiteralPath $sourceSpecification)) {
    throw "Explicit approved brief is unavailable: $sourceSpecification"
}
if (Test-Path -LiteralPath $sourceSpecification) {
    $sourceHash = (Get-FileHash -LiteralPath $sourceSpecification -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($sourceHash -ne $index.source_sha256) {
        throw 'Approved brief SHA-256 does not match the committed requirement index.'
    }
    $sourceRequirements = @([regex]::Matches(
        (Get-Content -Raw -LiteralPath $sourceSpecification),
        '(?m)^### (REQ-[A-Z-]+-\d{2})\.'
    ) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    if (($sourceRequirements -join ',') -ne ($requirements -join ',')) {
        throw 'Approved brief requirement IDs do not match the committed index.'
    }
    $sourceValidation = 'approved brief SHA-256 and requirement IDs'
} else {
    $sourceValidation = 'committed requirement index only; approved brief unavailable on this host'
}

$backlog = Get-Content -Raw -LiteralPath $backlogPath
$missing = @($requirements | Where-Object { $backlog -notmatch [regex]::Escape($_) })

if ($missing.Count -gt 0) {
    throw "Requirements without a backlog reference: $($missing -join ', ')"
}

Write-Output "Traceability OK: $($requirements.Count) requirements are referenced; source validation: $sourceValidation."
