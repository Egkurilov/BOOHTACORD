$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$verifier = Join-Path $PSScriptRoot 'verify-poc-01-evidence.ps1'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("voice-platform-poc-evidence-" + [guid]::NewGuid())

function New-Evidence {
    param(
        [string]$path,
        [string]$operatingSystem,
        [string]$architecture,
        [string]$presenter,
        [string]$observerMachine
    )

    [ordered]@{
        id = "poc-01-$operatingSystem-test"
        kind = 'poc-01'
        status = 'PASS'
        executed_at = '2026-09-19T00:00:00Z'
        environment = [ordered]@{
            presenter_machine = $presenter
            presenter_architecture = $architecture
            observer_machine = $observerMachine
            presenter_os = $operatingSystem
            observer_os = 'test observer OS'
            chrome_version = 'Chrome Stable test'
            livekit_image_digest = 'sha256:test'
            audio_devices = @('headphones')
        }
        scenario = [ordered]@{ game = 'test game'; capture_source = 'full-screen'; expected = @() }
        observations = [ordered]@{
            moving_game_video = $true
            game_audio = $true
            presenter_voice = $true
            no_sustained_digital_loop = $true
            moving_video_observation_seconds = 10
        }
        observer = 'physical observer'
        artifacts = @([ordered]@{ type = 'observer recording'; storage = 'secured-outside-repository'; contains = 'test proof' })
        failure_or_blocker = $null
        notes = $null
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path -Encoding utf8
}

function Invoke-Validator {
    param([string]$windowsPath, [string]$macPath)

    $priorPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $verifier -WindowsEvidence $windowsPath -MacEvidence $macPath 2>&1 | Out-String
        [pscustomobject]@{ exitCode = $LASTEXITCODE; output = $output }
    } finally {
        $ErrorActionPreference = $priorPreference
    }
}

New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    $windowsPath = Join-Path $testRoot 'windows.json'
    $macPath = Join-Path $testRoot 'macos.json'
    New-Evidence $windowsPath 'Windows' 'amd64' 'windows-presenter' 'windows-observer'
    New-Evidence $macPath 'macOS' 'arm64' 'mac-presenter' 'mac-observer'

    $valid = Invoke-Validator $windowsPath $macPath
    if ($valid.exitCode -ne 0 -or $valid.output -notmatch 'POC-01 evidence gate: PASS') {
        throw 'Expected valid POC evidence to pass.'
    }

    $mac = Get-Content -Raw $macPath | ConvertFrom-Json
    $mac.environment.presenter_architecture = 'x64'
    $mac | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $macPath -Encoding utf8
    $wrongArchitecture = Invoke-Validator $windowsPath $macPath
    if ($wrongArchitecture.exitCode -eq 0 -or $wrongArchitecture.output -notmatch 'macOS POC evidence is incomplete.') {
        throw 'Expected an Intel macOS record to fail.'
    }

    New-Evidence $macPath 'macOS' 'arm64' 'mac-presenter' 'mac-observer'
    $windows = Get-Content -Raw $windowsPath | ConvertFrom-Json
    $windows.status = 'BLOCKED'
    $windows | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $windowsPath -Encoding utf8
    $blocked = Invoke-Validator $windowsPath $macPath
    if ($blocked.exitCode -eq 0 -or $blocked.output -notmatch 'Windows POC evidence is incomplete.') {
        throw 'Expected a blocked Windows record to fail.'
    }

    $windows.status = 'PASS'
    $windows.observations.game_audio = $false
    $windows | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $windowsPath -Encoding utf8
    $noGameAudio = Invoke-Validator $windowsPath $macPath
    if ($noGameAudio.exitCode -eq 0) { throw 'A video-only record must not pass POC-01.' }

    $windows.observations.game_audio = $true
    $windows.environment.presenter_os = 'secret-token'
    $windows | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $windowsPath -Encoding utf8
    $secret = Invoke-Validator $windowsPath $macPath
    if ($secret.exitCode -eq 0 -or $secret.output -match 'secret-token') {
        throw 'Verifier must reject invalid evidence without leaking values.'
    }
} finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output 'POC-01 evidence verifier tests: OK'
