$paths = @{
    '/api/v1/me/sessions' = 'get'
    '/api/v1/me/sessions/{sessionID}' = 'delete'
    '/api/v1/me/sessions/revoke-others' = 'post'
}
foreach ($path in $paths.Keys) {
    $operation = $openApi.paths.$path.($paths[$path])
    if (-not $operation) { throw "Missing owned-session operation: $path" }
    foreach ($status in @('401','500')) {
        if (-not $operation.responses.$status) { throw "Missing session error $status in $path" }
    }
    if ($paths[$path] -ne 'get') {
        if (-not $operation.responses.'409') { throw "Account-switch conflict missing in $path" }
        if (-not ($operation.parameters | Where-Object { $_.name -eq 'X-Account-ID' -and $_.required })) {
            throw "Viewed account guard missing in $path"
        }
    }
}
$session = $openApi.components.schemas.OwnSession
if ($session.additionalProperties -ne $false) { throw 'Session DTO must reject unexpected fields.' }
foreach ($name in @('id','label','created_at','last_active_at','current')) {
    if ($session.required -notcontains $name) { throw "Session DTO missing $name" }
}
if (@($session.properties.PSObject.Properties).Count -ne 5) { throw 'Unexpected session DTO field.' }
if ($realtime.properties.kind.enum -notcontains 'session.state_changed') { throw 'Private session hint missing.' }
