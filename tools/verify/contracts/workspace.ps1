if ($null -eq $openApi.paths.'/api/v1/maintenance'.get) {
    throw 'Deployment contract must define GET /api/v1/maintenance.'
}

if ($openApi.paths.'/api/v1/maintenance'.get.responses.'200'.content.'application/json'.schema.'$ref' -ne '#/components/schemas/MaintenanceStatus') {
    throw 'Maintenance status must return the shared MaintenanceStatus schema.'
}

if ($null -eq $openApi.components.schemas.MaintenanceStatus.properties.active) {
    throw 'Maintenance status must expose only the active state.'
}

if ($null -eq $openApi.paths.'/api/v1/admin/accounts/{accountID}'.patch) {
    throw 'Auth contract must define PATCH /api/v1/admin/accounts/{accountID}.'
}

if ($null -eq $openApi.paths.'/api/v1/admin/categories'.post) {
    throw 'Channel contract must define POST /api/v1/admin/categories.'
}

if ($null -eq $openApi.paths.'/api/v1/channels'.get) {
    throw 'Channel contract must define GET /api/v1/channels.'
}

if ($null -eq $openApi.paths.'/api/v1/direct-messages'.post) {
    throw 'DM contract must define POST /api/v1/direct-messages.'
}

if ($null -eq $openApi.paths.'/api/v1/direct-messages'.get) {
    throw 'DM contract must define GET /api/v1/direct-messages.'
}

if ($null -eq $openApi.paths.'/api/v1/direct-message-candidates'.get) {
    throw 'DM contract must define GET /api/v1/direct-message-candidates.'
}

foreach ($schemaName in @('DirectMessageCandidate', 'DirectMessageCandidateList')) {
    if ($null -eq $openApi.components.schemas.$schemaName) {
        throw "DM contract must define $schemaName."
    }
}

if ($null -eq $openApi.components.schemas.DirectMessageListItem.properties.unread_count) {
    throw 'DM list contract must define unread_count.'
}
foreach ($schemaName in @('TextMessageCreateRequest', 'TextMessageEditRequest', 'DirectMessageMessageCreateRequest', 'DirectMessageMessageEditRequest', 'TextMessageHistoryItem', 'DirectMessageMessageHistoryItem')) {
    $mentions = $openApi.components.schemas.$schemaName.properties.mention_user_ids
    if ($null -eq $mentions -or $mentions.type -ne 'array' -or $mentions.uniqueItems -ne $true -or $mentions.items.format -ne 'uuid') {
        throw "Mentions contract must carry unique user IDs on $schemaName."
    }
}
foreach ($schemaName in @('TextMessageCreateRequest', 'DirectMessageMessageCreateRequest')) {
    $schema = $openApi.components.schemas.$schemaName
    if ($schema.properties.body.minLength -ne 0 -or
        $schema.required -notcontains 'body' -or
        $schema.anyOf.Count -ne 2 -or
        $schema.anyOf[0].properties.body.minLength -ne 1 -or
        $schema.anyOf[1].required -notcontains 'attachment_ids' -or
        $schema.anyOf[1].properties.attachment_ids.minItems -ne 1) {
        throw "$schemaName must allow an empty caption only with attachment IDs."
    }
}
if ($null -eq $openApi.components.schemas.Channel.properties.mention_count -or
    $null -eq $openApi.components.schemas.DirectMessageListItem.properties.mention_count) {
    throw 'Navigation contract must define caller-local mention counts for TEXT and DM.'
}
