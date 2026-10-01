$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '../tools/verify/android_release_signing/verify-android-release-signing.ps1') @args
if ($LASTEXITCODE) { exit $LASTEXITCODE }
