$guildProfile = $openApi.paths.'/api/v1/guild-profile'.get
$guildSettings = $openApi.paths.'/api/v1/admin/guild-settings'
if ($null -eq $guildProfile -or $null -eq $guildSettings.get -or $null -eq $guildSettings.patch) {
    throw 'Guild profile and administrator settings routes are required.'
}
$profile = $openApi.components.schemas.GuildProfile
if ($profile.additionalProperties -ne $false -or
    @($profile.properties.PSObject.Properties).Count -ne 2 -or
    $profile.required -notcontains 'name' -or $profile.required -notcontains 'revision') {
    throw 'Public guild profile must expose only name and revision.'
}
$patch = $openApi.components.schemas.GuildSettingsUpdateRequest
if ($patch.required -notcontains 'expected_revision' -or
    $patch.additionalProperties -ne $false -or
    $null -eq $guildSettings.patch.responses.'401' -or
    $null -eq $guildSettings.patch.responses.'403' -or
    $null -eq $guildSettings.patch.responses.'409') {
    throw 'Guild updates must define strict input, session/administrator ACL and revision conflict.'
}
foreach ($name in @('TextMessage', 'TextMessageHistoryItem', 'TextMessageSearchResult')) {
    $schema = $openApi.components.schemas.$name
    if ($schema.required -notcontains 'kind' -or
        $schema.properties.kind.enum -notcontains 'SYSTEM_WELCOME') {
        throw "Message kind must survive $name."
    }
}
if ($openApi.components.schemas.MessageSearchResult.required -notcontains 'message_kind') {
    throw 'Unified search must distinguish conversation kind from message_kind.'
}
$hint = $realtime.allOf | Where-Object { $_.if.properties.kind.const -eq 'guild.profile.updated' } | Select-Object -First 1
if ($realtime.properties.kind.enum -notcontains 'guild.profile.updated' -or
    $null -eq $hint -or
    $hint.then.properties.payload.additionalProperties -ne $false -or
    @($hint.then.properties.payload.properties.PSObject.Properties).Count -ne 1 -or
    $hint.then.properties.payload.required -notcontains 'revision') {
    throw 'Guild realtime hint must expose only revision.'
}
