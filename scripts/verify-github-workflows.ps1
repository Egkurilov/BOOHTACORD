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

$tracked = @(git -C $root ls-files -- artifacts desktop/build frontend/dist desktop/packages/flutter_webrtc/third_party)
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect tracked build outputs.' }
$generated = @($tracked | Where-Object {
    $_ -match '^artifacts/.*\.(apk|aab|ipa|zip|dmg|msix|exe|dll|pdb|lib)$' -or
    $_ -match '^(desktop/build|frontend/dist)/' -or
    $_ -match '^desktop/packages/flutter_webrtc/third_party/(downloads|libwebrtc)/'
})
if ($generated.Count -gt 0) {
    throw "Generated build outputs are tracked by Git: $($generated -join ', ')"
}

$windows = Get-Content -LiteralPath (Join-Path $root '.github/workflows/flutter-windows.yaml') -Raw
if ($windows -notmatch 'uses:\s*actions/upload-artifact@v4' -or
    $windows -notmatch 'path:\s*desktop/build/windows/x64/runner/Release/' -or
    $windows -notmatch 'if-no-files-found:\s*error' -or
    $windows -notmatch 'retention-days:\s*30') {
    throw 'Windows CI must retain the full release directory as a fail-closed workflow artifact.'
}
foreach ($required in @('workflow_call:', 'runs-on: windows-2022',
    'uses: subosito/flutter-action@v2', 'flutter-version: 3.47.5',
    'flutter build windows --release --no-pub')) {
    if (-not $windows.Contains($required)) {
        throw "Windows CI must run on a hosted runner before merge: $required"
    }
}
$macos = Get-Content -LiteralPath (Join-Path $root '.github/workflows/flutter-macos.yaml') -Raw
if ($macos -notmatch 'bash scripts/macos_release/package.sh' -or
    $macos -notmatch 'uses:\s*actions/upload-artifact@v4' -or
    $macos -notmatch 'if-no-files-found:\s*error' -or
    $macos -notmatch 'retention-days:\s*30') {
    throw 'macOS CI must package and retain its ZIP and checksum as a workflow artifact.'
}
$ci = Get-Content -LiteralPath (Join-Path $root '.github/workflows/ci.yaml') -Raw
$flutterCiPath = Join-Path $root '.github/workflows/ci-flutter.yaml'
if ($ci -notmatch '(?m)^  flutter:\s*\r?\n    uses: \./\.github/workflows/ci-flutter\.yaml' -or
    $ci -notmatch '(?m)^  windows:\s*\r?\n    uses: \./\.github/workflows/flutter-windows\.yaml' -or
    $ci -notmatch 'needs: \[contracts, backend, frontend, flutter, windows\]' -or
    -not (Test-Path -LiteralPath $flutterCiPath)) {
    throw 'Pull-request CI must run Flutter and Windows gates before publishing images.'
}
$flutterCi = Get-Content -LiteralPath $flutterCiPath -Raw
foreach ($required in @(
    'workflow_call:', 'runs-on: ubuntu-24.04', 'flutter-version: 3.47.5',
    'flutter pub get --enforce-lockfile', 'flutter test --no-pub',
    'working-directory: desktop/packages/livekit_client',
    'working-directory: desktop/packages/flutter_webrtc',
    'flutter analyze --no-pub', 'flutter build apk --debug --no-pub'
)) {
    if (-not $flutterCi.Contains($required)) {
        throw "Flutter CI gate is missing: $required"
    }
}
if ($flutterCi -notmatch 'uses:\s*actions/upload-artifact@v4' -or
    $flutterCi -notmatch 'path:\s*desktop/build/app/outputs/flutter-apk/app-debug\.apk' -or
    $flutterCi -notmatch 'if-no-files-found:\s*error' -or
    $flutterCi -notmatch 'retention-days:\s*30') {
    throw 'Flutter CI must retain the built debug APK as a fail-closed workflow artifact.'
}
$android = Get-Content -LiteralPath (Join-Path $root '.github/workflows/android-release.yaml') -Raw
if ($android -notmatch '(?m)^  quality:\s*\r?\n    uses: \./\.github/workflows/ci-flutter\.yaml' -or
    $android -notmatch '(?m)^  android-release:\s*\r?\n    needs: quality' -or
    $android -notmatch 'runs-on:\s*ubuntu-24\.04' -or
    $android -notmatch 'uses:\s*actions/upload-artifact@v4' -or
    $android -notmatch 'path:\s*desktop/build/release-assets/\*\.apk' -or
    $android -notmatch 'if-no-files-found:\s*error') {
    throw 'Android release must pass the Flutter gate before signing and publication.'
}
Write-Output 'GitHub workflow routing: OK'
