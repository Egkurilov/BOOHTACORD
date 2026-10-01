$ErrorActionPreference = 'Stop'

$openApiPath = Join-Path $PSScriptRoot '..\..\..\contracts\openapi.yaml'
$realtimePath = Join-Path $PSScriptRoot '..\..\..\contracts\realtime.schema.json'
$mobileContractPath = Join-Path $PSScriptRoot '..\..\..\contracts\mobile-client-contract.md'

foreach ($path in @($openApiPath, $realtimePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Contract is unavailable: $path"
    }
}

if (-not (Test-Path -LiteralPath $mobileContractPath)) {
    throw "Mobile client contract is unavailable: $mobileContractPath"
}

$mobileContract = Get-Content -Raw -LiteralPath $mobileContractPath
foreach ($requiredText in @('openapi.yaml', 'realtime.schema.json', 'Voice lease', 'LiveKit credential')) {
    if ($mobileContract -notmatch [regex]::Escape($requiredText)) {
        throw "Mobile client contract is missing required section: $requiredText"
    }
}

$openApi = Get-Content -Raw -LiteralPath $openApiPath | ConvertFrom-Json
$realtime = Get-Content -Raw -LiteralPath $realtimePath | ConvertFrom-Json

. (Join-Path $PSScriptRoot 'realtime.ps1')
. (Join-Path $PSScriptRoot 'identity.ps1')
. (Join-Path $PSScriptRoot 'workspace.ps1')
. (Join-Path $PSScriptRoot 'direct_messages.ps1')
. (Join-Path $PSScriptRoot 'text_channels.ps1')
. (Join-Path $PSScriptRoot 'voice.ps1')
. (Join-Path $PSScriptRoot 'security.ps1')
Write-Output 'Contracts OK.'
