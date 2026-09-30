$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$names = @(
    'android-release.yaml', 'audit-attachment-volume.yaml', 'deploy-production.yaml',
    'flutter-macos.yaml', 'flutter-windows.yaml', 'macos-release.yaml',
    'qa08-active-upload.yaml', 'qa11-preflight.yaml', 'rehearse-compatible-rollback.yaml'
)
foreach ($name in $names) {
    $path = Join-Path $root ".github/workflows/$name"
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing GitHub workflow: $name" }
    $source = Get-Content -LiteralPath $path -Raw
    if ($source -match 'gitverse\.|GITVERSE_OUTPUT|api\.gitverse\.ru|\.gitverse/workflows') {
        throw "GitVerse-specific runtime remains in $name"
    }
}
if (Test-Path -LiteralPath (Join-Path $root '.gitverse/workflows')) {
    throw 'Legacy GitVerse workflow directory remains active.'
}
$deploy = Get-Content -LiteralPath (Join-Path $root '.github/workflows/deploy-production.yaml') -Raw
if ($deploy -notmatch 'GITHUB_OUTPUT' -or $deploy -notmatch "github\.ref_name == 'master'" -or
    $deploy -notmatch 'group: v-bootybay-production') {
    throw 'GitHub production delivery guards are incomplete.'
}
Write-Output 'GitHub workflow routing: OK'
