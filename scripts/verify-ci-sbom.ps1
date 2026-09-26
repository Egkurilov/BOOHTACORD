$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$workflow = Get-Content -LiteralPath (Join-Path $projectRoot '.github/workflows/ci.yml') -Raw
$publisherSteps = @()

if ($workflow -match '(?m)^  deploy:') {
    throw 'GitHub CI must not be a second production writer; see ADR-010.'
}

foreach ($name in @('API', 'web')) {
    $step = [regex]::Match(
        $workflow,
        "(?ms)^      - name: Build and push $name image\r?\n(?<body>.*?)(?=^      - name:|^  deploy:)"
    )
    if (-not $step.Success) {
        throw "Missing $name image publisher."
    }
    $body = $step.Groups['body'].Value
    if ($body -notmatch '(?m)^        uses: docker/build-push-action@v6$' -or $body -notmatch '(?m)^          push: true$' -or $body -notmatch '(?m)^          sbom: true$' -or $body -notmatch 'github\.sha') {
        throw "$name publisher must push a commit-SHA image with an SBOM attestation."
    }
    $publisherSteps += $body
}

foreach ($reference in @(
    'api_image=ghcr.io/${{ github.repository_owner }}/voice-platform-api@${{ steps.api-image.outputs.digest }}',
    'web_image=ghcr.io/${{ github.repository_owner }}/voice-platform-web@${{ steps.web-image.outputs.digest }}'
)) {
    if (-not $workflow.Contains($reference)) {
        throw "Missing digest-qualified release reference: $reference"
    }
}

Write-Output 'CI SBOM contract: OK'
