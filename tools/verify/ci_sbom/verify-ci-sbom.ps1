$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Push-Location $projectRoot
try {
    python -m tools.verify.workflows.delivery
    if ($LASTEXITCODE -ne 0) { throw 'Signed artifact delivery policy failed.' }
    python -m unittest tools.verify.oci.test_verify_oci
    if ($LASTEXITCODE -ne 0) { throw 'OCI SBOM/provenance verification failed.' }
} finally { Pop-Location }
Write-Output 'CI SBOM contract: OK'
