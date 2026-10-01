if ($null -eq $openApi.paths.'/api/v1/direct-messages/{directMessageID}/messages'.post) {
    throw 'DM contract must define POST /api/v1/direct-messages/{directMessageID}/messages.'
}

if ($null -eq $openApi.components.schemas.DirectMessageMessageCreateRequest.properties.reply_to_id) {
    throw 'DM contract must define reply_to_id for direct-message creation.'
}

foreach ($schemaName in @('DirectMessageMessage', 'DirectMessageMessageHistoryItem')) {
    if ($null -eq $openApi.components.schemas.$schemaName.properties.reply_to_id) {
        throw "DM contract must define reply_to_id for $schemaName."
    }
}

if ($openApi.components.schemas.DirectMessageMessageHistoryItem.properties.reply_preview.'$ref' -ne '#/components/schemas/DirectMessageReplyPreview') {
    throw 'DM history contract must define the DirectMessageReplyPreview reference.'
}

if ($null -eq $openApi.components.schemas.DirectMessageReplyPreview) {
    throw 'DM contract must define DirectMessageReplyPreview.'
}

if ($null -eq $openApi.paths.'/api/v1/direct-messages/{directMessageID}/messages'.get) {
    throw 'DM contract must define GET /api/v1/direct-messages/{directMessageID}/messages.'
}

if ($null -eq $openApi.paths.'/api/v1/direct-messages/{directMessageID}/search'.get) {
    throw 'DM contract must define GET /api/v1/direct-messages/{directMessageID}/search.'
}

foreach ($schemaName in @('DirectMessageSearchPage', 'DirectMessageSearchResult')) {
    if ($null -eq $openApi.components.schemas.$schemaName) {
        throw "DM contract must define $schemaName."
    }
}

if ($null -eq $openApi.paths.'/api/v1/direct-messages/{directMessageID}/messages/{messageID}'.patch) {
    throw 'DM contract must define PATCH /api/v1/direct-messages/{directMessageID}/messages/{messageID}.'
}

if ($null -eq $openApi.paths.'/api/v1/direct-messages/{directMessageID}/messages/{messageID}'.delete) {
    throw 'DM contract must define DELETE /api/v1/direct-messages/{directMessageID}/messages/{messageID}.'
}

if ($null -eq $openApi.paths.'/api/v1/direct-messages/{directMessageID}/read-cursor'.put) {
    throw 'DM contract must define PUT /api/v1/direct-messages/{directMessageID}/read-cursor.'
}

foreach ($schemaName in @('DirectMessageReadCursorRequest', 'DirectMessageReadCursor')) {
    if ($null -eq $openApi.components.schemas.$schemaName) {
        throw "DM contract must define $schemaName."
    }
}

if ($null -eq $openApi.paths.'/api/v1/channels/{channelID}/messages'.post) {
    throw 'Chat contract must define POST /api/v1/channels/{channelID}/messages.'
}

$dmUpload = $openApi.paths.'/api/v1/direct-messages/{directMessageID}/attachments'.post
if ($null -eq $dmUpload -or
    $dmUpload.operationId -ne 'uploadDirectMessageAttachment' -or
    $dmUpload.responses.'201'.content.'application/json'.schema.'$ref' -ne '#/components/schemas/AttachmentUpload' -or
    $null -eq $openApi.components.schemas.DirectMessageMessageCreateRequest.properties.attachment_ids) {
    throw 'DM contract must define private upload and bounded attachment IDs on send.'
}
$dmDownload = $openApi.paths.'/api/v1/direct-messages/{directMessageID}/attachments/{attachmentID}'.get
$dmPreview = $openApi.paths.'/api/v1/direct-messages/{directMessageID}/attachments/{attachmentID}/preview'.get
if ($null -eq $dmDownload -or $dmDownload.operationId -ne 'downloadDirectMessageAttachment' -or
    $null -eq $dmDownload.responses.'404' -or
    $null -eq $dmPreview -or $dmPreview.operationId -ne 'previewDirectMessageAttachment' -or
    $null -eq $dmPreview.responses.'404') {
    throw 'DM contract must define participant-protected download and normalized preview.'
}
if ($openApi.components.schemas.DirectMessageMessageHistoryItem.required -notcontains 'attachments' -or
    $openApi.components.schemas.DirectMessageMessageHistoryItem.properties.attachments.items.'$ref' -ne '#/components/schemas/TextMessageAttachment') {
    throw 'DM history must expose protected attachment metadata without storage keys.'
}
