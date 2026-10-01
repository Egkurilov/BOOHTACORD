if ($null -eq $openApi.paths.'/api/v1/channels/{channelID}/messages'.get) {
    throw 'Chat contract must define GET /api/v1/channels/{channelID}/messages.'
}

$channelReadCursor = $openApi.paths.'/api/v1/channels/{channelID}/read-cursor'.put
if ($null -eq $channelReadCursor -or
    $channelReadCursor.operationId -ne 'advanceTextChannelReadCursor' -or
    $channelReadCursor.requestBody.content.'application/json'.schema.'$ref' -ne '#/components/schemas/ChannelReadCursorRequest' -or
    $channelReadCursor.responses.'200'.content.'application/json'.schema.'$ref' -ne '#/components/schemas/ChannelReadCursor' -or
    $null -eq $openApi.components.schemas.Channel.properties.unread_count) {
    throw 'Chat contract must define caller-local TEXT channel unread counters and monotonic read cursor.'
}

if ($null -eq $openApi.paths.'/api/v1/channels/{channelID}/search'.get) {
    throw 'Chat contract must define GET /api/v1/channels/{channelID}/search.'
}

foreach ($schemaName in @('TextMessageSearchPage', 'TextMessageSearchResult')) {
    if ($null -eq $openApi.components.schemas.$schemaName) {
        throw "Chat contract must define $schemaName."
    }
}

if ($null -eq $openApi.paths.'/api/v1/channels/{channelID}/messages/{messageID}'.patch) {
    throw 'Chat contract must define PATCH /api/v1/channels/{channelID}/messages/{messageID}.'
}

if ($null -eq $openApi.paths.'/api/v1/channels/{channelID}/messages/{messageID}'.delete) {
    throw 'Chat contract must define DELETE /api/v1/channels/{channelID}/messages/{messageID}.'
}

if ($null -eq $openApi.paths.'/api/v1/admin/categories/{categoryID}/channels'.post) {
    throw 'Channel contract must define POST /api/v1/admin/categories/{categoryID}/channels.'
}

if ($null -eq $openApi.paths.'/api/v1/admin/categories/order'.put) {
    throw 'Channel contract must define PUT /api/v1/admin/categories/order.'
}

if ($null -eq $openApi.paths.'/api/v1/admin/categories/{categoryID}'.patch) {
    throw 'Channel contract must define PATCH /api/v1/admin/categories/{categoryID}.'
}

$renameChannel = $openApi.paths.'/api/v1/admin/channels/{channelID}'.patch
if ($null -eq $renameChannel -or
    $renameChannel.operationId -ne 'renameChannel' -or
    $renameChannel.requestBody.content.'application/json'.schema.'$ref' -ne '#/components/schemas/ChannelRenameRequest' -or
    $renameChannel.responses.'200'.content.'application/json'.schema.'$ref' -ne '#/components/schemas/ChannelRenameResult' -or
    $null -eq $renameChannel.responses.'403' -or $null -eq $renameChannel.responses.'409') {
    throw 'Channel contract must define administrator-only revision-guarded PATCH /api/v1/admin/channels/{channelID}.'
}

if ($null -eq $openApi.paths.'/api/v1/admin/channels/{channelID}/category'.patch) {
    throw 'Channel contract must define PATCH /api/v1/admin/channels/{channelID}/category.'
}

if ($null -eq $openApi.paths.'/api/v1/admin/categories/{categoryID}/channels/order'.put) {
    throw 'Channel contract must define PUT /api/v1/admin/categories/{categoryID}/channels/order.'
}

if ($null -eq $openApi.paths.'/api/v1/admin/channels/{channelID}'.delete) {
    throw 'Channel contract must define DELETE /api/v1/admin/channels/{channelID}.'
}

if ($null -eq $openApi.paths.'/api/v1/admin/voice-channels/{channelID}/close-admission'.post) {
    throw 'Channel contract must define POST /api/v1/admin/voice-channels/{channelID}/close-admission.'
}
