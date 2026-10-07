$ErrorActionPreference = 'Stop'

$openApiPath = Join-Path $PSScriptRoot '..\..\..\contracts\openapi.yaml'
$realtimePath = Join-Path $PSScriptRoot '..\..\..\contracts\realtime.schema.json'
$mobileContractPath = Join-Path $PSScriptRoot '..\..\..\contracts\mobile-client-contract.md'
$clientUpdateSchemaPath = Join-Path $PSScriptRoot '..\..\..\contracts\client-release-catalog.schema.json'
$clientUpdateFixturesPath = Join-Path $PSScriptRoot '..\..\..\contracts\client-update-evaluator.fixtures.json'
$screenShareProfileSchemaPath = Join-Path $PSScriptRoot '..\..\..\contracts\screen-share-profile-v1.schema.json'
$screenShareProfileCatalogPath = Join-Path $PSScriptRoot '..\..\..\contracts\screen-share-profile-v1.catalog.json'
$screenShareProfileFixturesPath = Join-Path $PSScriptRoot '..\..\..\contracts\screen-share-profile-v1.fixtures.json'
$screenShareSfuSmokeEvidenceSchemaPath = Join-Path $PSScriptRoot '..\..\..\contracts\screen-share-sfu-smoke-evidence-v1.schema.json'

foreach ($path in @($openApiPath, $realtimePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Contract is unavailable: $path"
    }
}

foreach ($path in @($clientUpdateSchemaPath, $clientUpdateFixturesPath, $screenShareProfileSchemaPath, $screenShareProfileCatalogPath, $screenShareProfileFixturesPath, $screenShareSfuSmokeEvidenceSchemaPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Client or screen-share contract is unavailable: $path" }
    Get-Content -Raw -LiteralPath $path | ConvertFrom-Json | Out-Null
}

if (-not (Test-Path -LiteralPath $mobileContractPath)) {
    throw "Mobile client contract is unavailable: $mobileContractPath"
}

$mobileContract = Get-Content -Raw -LiteralPath $mobileContractPath
foreach ($requiredText in @('openapi.yaml', 'realtime.schema.json', 'Voice lease', 'LiveKit credential', 'Client update policy')) {
    if ($mobileContract -notmatch [regex]::Escape($requiredText)) {
        throw "Mobile client contract is missing required section: $requiredText"
    }
}

$openApi = Get-Content -Raw -LiteralPath $openApiPath | ConvertFrom-Json
$realtime = Get-Content -Raw -LiteralPath $realtimePath | ConvertFrom-Json

. (Join-Path $PSScriptRoot 'realtime.ps1')
. (Join-Path $PSScriptRoot 'guild_lifecycle.ps1')
. (Join-Path $PSScriptRoot 'identity.ps1')
. (Join-Path $PSScriptRoot 'own_sessions.ps1')
. (Join-Path $PSScriptRoot 'message_delivery.ps1')
. (Join-Path $PSScriptRoot 'workspace.ps1')
. (Join-Path $PSScriptRoot 'direct_messages.ps1')
. (Join-Path $PSScriptRoot 'text_channels.ps1')
. (Join-Path $PSScriptRoot 'voice.ps1')
. (Join-Path $PSScriptRoot 'screen_preview.ps1')
. (Join-Path $PSScriptRoot 'security.ps1')
. (Join-Path $PSScriptRoot 'role_permissions.ps1')
. (Join-Path $PSScriptRoot 'telemetry.ps1')
Write-Output 'Contracts OK.'
