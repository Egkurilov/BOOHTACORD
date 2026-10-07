$begin = $openApi.paths.'/api/v1/voice/leases/{leaseID}/screen-previews/v1'.post
$upload = $openApi.paths.'/api/v1/voice/leases/{leaseID}/screen-previews/v1/{generationID}'.put
$invalidate = $openApi.paths.'/api/v1/voice/leases/{leaseID}/screen-previews/v1/{generationID}'.delete
$read = $openApi.paths.'/api/v1/voice/screen-previews/v1/leases/{leaseID}/{generationID}'.get
if ($null -eq $begin -or $begin.operationId -ne 'beginScreenPreviewGeneration' -or $begin.description -notmatch 'exact current unmuted LiveKit ScreenShare track') {
    throw 'Screen preview generation must be minted only for a server-verified current publisher.'
}
if ($null -eq $upload -or $upload.requestBody.content.'image/jpeg'.schema.maxLength -ne 14336 -or
    $upload.parameters.name -notcontains 'X-Screen-Preview-Revision' -or
    $null -eq $upload.responses.'413' -or $null -eq $upload.responses.'415') {
    throw 'Screen preview upload must have a versioned bounded JPEG and revision contract.'
}
if ($null -eq $invalidate -or $invalidate.operationId -ne 'invalidateScreenPreviewGeneration') {
    throw 'Screen preview generation must expose explicit invalidation.'
}
if ($null -eq $read -or $read.responses.'200'.content.'image/jpeg'.schema.maxLength -ne 14336 -or
    $read.responses.'200'.headers.'Cache-Control'.schema.const -ne 'private, no-store, max-age=0' -or
    $null -eq $read.responses.'204') {
    throw 'Screen preview reads must be private/no-store and support latest-revision hints.'
}
$hint = $openApi.components.schemas.ScreenPreviewHint
if ($hint.additionalProperties -ne $false -or $hint.properties.PSObject.Properties.Name.Count -ne 3 -or ($hint.properties.PSObject.Properties.Name -contains 'jpeg')) {
    throw 'Realtime preview hints may contain only lease, generation and revision metadata.'
}
$previewEvent = $realtime.allOf | Where-Object { $_.if.properties.kind.const -eq 'screen_preview.updated' } | Select-Object -First 1
if ($realtime.properties.kind.enum -notcontains 'screen_preview.updated' -or $null -eq $previewEvent -or
    $previewEvent.then.properties.payload.additionalProperties -ne $false -or
    $previewEvent.then.properties.payload.required.Count -ne 3 -or
    ($previewEvent.then.properties.payload.properties.PSObject.Properties.Name -contains 'jpeg')) {
    throw 'Realtime preview event may carry only bounded revision hints, never image bytes.'
}
$invalidated = $realtime.allOf | Where-Object { $_.if.properties.kind.const -eq 'screen_preview.invalidated' } | Select-Object -First 1
if ($realtime.properties.kind.enum -notcontains 'screen_preview.invalidated' -or $null -eq $invalidated -or
    $invalidated.then.properties.payload.additionalProperties -ne $false -or
    $invalidated.then.properties.payload.required.Count -ne 2) {
    throw 'Realtime preview invalidation may carry only lease and generation metadata.'
}
