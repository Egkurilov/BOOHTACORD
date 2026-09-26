param(
    [Parameter(Mandatory = $true)][string]$WindowsEvidence,
    [Parameter(Mandatory = $true)][string]$MacEvidence
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Test-Text {
    param($Value)
    return ($Value -is [string]) -and (-not [string]::IsNullOrWhiteSpace($Value))
}

function Read-Record {
    param([string]$Path, [string]$Label, [string]$OperatingSystem)

    $failure = "$Label POC evidence is incomplete."
    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw $failure }
        $record = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        if ($record.kind -cne 'poc-01' -or $record.status -cne 'PASS') { throw $failure }
        if (-not (Test-Text $record.executed_at)) { throw $failure }
        $timestamp = [DateTimeOffset]::MinValue
        if (-not [DateTimeOffset]::TryParse($record.executed_at, [ref]$timestamp)) { throw $failure }

        $environment = $record.environment
        if ($environment.presenter_os -cne $OperatingSystem) { throw $failure }
        if ($OperatingSystem -ceq 'macOS' -and $environment.presenter_architecture -cne 'arm64') { throw $failure }
        foreach ($field in @('presenter_machine', 'observer_machine', 'observer_os', 'chrome_version', 'livekit_image_digest')) {
            if (-not (Test-Text $environment.$field)) { throw $failure }
        }
        if ($environment.presenter_machine -ceq $environment.observer_machine) { throw $failure }
        if (-not (Test-Text $record.observer)) { throw $failure }
        if (-not (Test-Text $record.scenario.game) -or -not (Test-Text $record.scenario.capture_source)) { throw $failure }

        $observations = $record.observations
        foreach ($field in @('moving_game_video', 'game_audio', 'presenter_voice', 'no_sustained_digital_loop')) {
            if ($observations.$field -isnot [bool] -or -not $observations.$field) { throw $failure }
        }
        $seconds = $observations.moving_video_observation_seconds
        if ($seconds -isnot [int] -and $seconds -isnot [long] -and $seconds -isnot [double]) { throw $failure }
        if ($seconds -lt 10) { throw $failure }

        if (@($record.artifacts).Count -eq 0) { throw $failure }
        foreach ($artifact in @($record.artifacts)) {
            if ($artifact.storage -cne 'secured-outside-repository') { throw $failure }
            if (-not (Test-Text $artifact.type)) { throw $failure }
        }
        return $record
    } catch {
        throw $failure
    }
}

$windows = Read-Record -Path $WindowsEvidence -Label 'Windows' -OperatingSystem 'Windows'
$mac = Read-Record -Path $MacEvidence -Label 'macOS' -OperatingSystem 'macOS'
if ($windows.environment.presenter_machine -ceq $mac.environment.presenter_machine) {
    throw 'macOS POC evidence is incomplete.'
}

Write-Output 'POC-01 evidence gate: PASS'
