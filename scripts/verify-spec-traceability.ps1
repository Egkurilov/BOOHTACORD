$ErrorActionPreference = 'Stop'

$sourceSpecification = 'C:\Users\egkur\Downloads\TZ_Voice_Platform_v1.0.md'
$backlogPath = Join-Path $PSScriptRoot '..\backlog\tasks.yaml'

if (-not (Test-Path -LiteralPath $sourceSpecification)) {
    throw "Source specification is unavailable: $sourceSpecification"
}

if (-not (Test-Path -LiteralPath $backlogPath)) {
    throw "Backlog is unavailable: $backlogPath"
}

$requirements = [regex]::Matches(
    (Get-Content -Raw -LiteralPath $sourceSpecification),
    '(?m)^### (REQ-[A-Z-]+-\d{2})\.'
) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

$backlog = Get-Content -Raw -LiteralPath $backlogPath
$missing = @($requirements | Where-Object { $backlog -notmatch [regex]::Escape($_) })

if ($missing.Count -gt 0) {
    throw "Requirements without a backlog reference: $($missing -join ', ')"
}

Write-Output "Traceability OK: $($requirements.Count) requirements are referenced."
