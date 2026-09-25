$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$gradlePath = Join-Path $root 'desktop/android/app/build.gradle.kts'
$gradle = Get-Content -LiteralPath $gradlePath -Raw
$ignore = Get-Content -LiteralPath (Join-Path $root 'desktop/android/.gitignore') -Raw

if ($gradle -match 'signingConfigs\.getByName\("debug"\)') {
    throw 'Android release must not use the debug signing config.'
}

foreach ($name in @(
    'BOOHTACORD_ANDROID_KEYSTORE_FILE',
    'BOOHTACORD_ANDROID_KEYSTORE_PASSWORD',
    'BOOHTACORD_ANDROID_KEY_ALIAS',
    'BOOHTACORD_ANDROID_KEY_PASSWORD'
)) {
    if (-not $gradle.Contains($name)) {
        throw "Android release signing is missing external input $name."
    }
}

if (-not $gradle.Contains('key.properties') -or
    -not $gradle.Contains('gradle.taskGraph.whenReady') -or
    -not $gradle.Contains('releaseSigning')) {
    throw 'Android release must load ignored local signing data and fail before release tasks without it.'
}

foreach ($pattern in @('key.properties', '**/*.keystore', '**/*.jks')) {
    if (-not $ignore.Contains($pattern)) {
        throw "Android gitignore must cover $pattern."
    }
}

foreach ($path in @(
    'desktop/android/key.properties',
    'desktop/android/app/release.jks',
    'desktop/android/app/release.keystore'
)) {
    git -C $root check-ignore -q -- $path
    if ($LASTEXITCODE -ne 0) { throw "Git does not ignore $path." }
}

$tracked = git -C $root ls-files -- desktop/android
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect tracked Android files.' }
if ($tracked | Where-Object { $_ -match '(key\.properties|\.(jks|keystore))$' }) {
    throw 'A signing credential or keystore is tracked by Git.'
}

Write-Output 'Android release-signing source guard: PASS'
