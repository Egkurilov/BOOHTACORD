foreach ($authPath in @('/api/v1/auth/register', '/api/v1/auth/login', '/api/v1/auth/password-reset/complete', '/api/v1/admin/password-reset-links')) {
    if ($openApi.paths.$authPath.post.requestBody.required -ne $true) {
        throw "Auth contract must define a required POST request body for $authPath."
    }
}

if ($openApi.components.schemas.Account.properties.PSObject.Properties.Name -contains 'password_hash') {
    throw 'The public Account schema must not expose password_hash.'
}

$realtime = Get-Content -Raw -LiteralPath $realtimePath | ConvertFrom-Json
if ($realtime.'$schema' -notmatch 'json-schema.org' -or $realtime.properties.kind.enum.Count -lt 1) {
    throw 'Realtime contract must be a JSON Schema with an explicit event kind enum.'
}
