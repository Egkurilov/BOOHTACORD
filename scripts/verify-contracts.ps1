$ErrorActionPreference = 'Stop'

$openApiPath = Join-Path $PSScriptRoot '..\contracts\openapi.yaml'
$realtimePath = Join-Path $PSScriptRoot '..\contracts\realtime.schema.json'
$mobileContractPath = Join-Path $PSScriptRoot '..\contracts\mobile-client-contract.md'

foreach ($path in @($openApiPath, $realtimePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Contract is unavailable: $path"
    }
}

if (-not (Test-Path -LiteralPath $mobileContractPath)) {
    throw "Mobile client contract is unavailable: $mobileContractPath"
}

$mobileContract = Get-Content -Raw -LiteralPath $mobileContractPath
foreach ($requiredText in @('openapi.yaml', 'realtime.schema.json', 'Voice lease', 'LiveKit credential')) {
    if ($mobileContract -notmatch [regex]::Escape($requiredText)) {
        throw "Mobile client contract is missing required section: $requiredText"
    }
}

$openApi = Get-Content -Raw -LiteralPath $openApiPath | ConvertFrom-Json
$realtime = Get-Content -Raw -LiteralPath $realtimePath | ConvertFrom-Json
foreach ($kind in @('direct_message.message_created', 'direct_message.message_updated', 'direct_message.message_deleted')) {
    if ($realtime.properties.kind.enum -notcontains $kind) {
        throw "Realtime contract must define private $kind."
    }
    $branch = $realtime.allOf | Where-Object { $_.if.properties.kind.const -eq $kind } | Select-Object -First 1
    if ($null -eq $branch -or
        $branch.then.properties.payload.required -notcontains 'direct_message_id' -or
        $branch.then.properties.payload.required -notcontains 'message_id' -or
        $null -ne $branch.then.properties.payload.properties.body -or
        $branch.then.properties.payload.additionalProperties -ne $false) {
        throw "Realtime $kind must expose only typed DM identifiers."
    }
}
$channelUpdated = $realtime.allOf | Where-Object { $_.if.properties.kind.const -eq 'channel.updated' } | Select-Object -First 1
if ($null -eq $channelUpdated -or
    $channelUpdated.then.properties.payload.required -notcontains 'revision' -or
    $channelUpdated.then.properties.payload.properties.revision.type -ne 'integer' -or
    $channelUpdated.then.properties.payload.additionalProperties -ne $false) {
    throw 'Realtime channel.updated must carry only a typed topology revision.'
}
$leaseRevoked = $realtime.allOf | Where-Object { $_.if.properties.kind.const -eq 'voice.lease_revoked' } | Select-Object -First 1
if ($null -eq $leaseRevoked -or
    $leaseRevoked.then.properties.payload.required -notcontains 'lease_id' -or
    $leaseRevoked.then.properties.payload.required -notcontains 'reason' -or
    $leaseRevoked.then.properties.payload.additionalProperties -ne $false) {
    throw 'Realtime voice.lease_revoked must identify only the caller lease and reason.'
}
$resync = $realtime.allOf | Where-Object { $_.if.properties.kind.const -eq 'connection.resync_required' } | Select-Object -First 1
if ($null -eq $resync -or
    $resync.then.properties.payload.required -notcontains 'reason' -or
    $resync.then.properties.payload.additionalProperties -ne $false) {
    throw 'Realtime resync_required must carry a typed reason.'
}
$realtimeUpgrade = $openApi.paths.'/api/v1/realtime'.get
if ($null -eq $realtimeUpgrade -or
    $realtimeUpgrade.parameters[0].name -ne 'after' -or
    $realtimeUpgrade.parameters[0].schema.format -ne 'uuid' -or
    $null -eq $realtimeUpgrade.responses.'101' -or
    $realtimeUpgrade.description -notmatch '7-day') {
    throw 'Realtime upgrade contract must define the acknowledged after cursor and retention.'
}
if ($openApi.openapi -notmatch '^3\.1\.' -or $null -eq $openApi.paths.'/api/v1/health') {
    throw 'OpenAPI must be 3.1.x and define GET /api/v1/health.'
}

$healthResponse = $openApi.paths.'/api/v1/health'.get.responses.'200'.content.'application/json'.schema.'$ref'
if ($healthResponse -ne '#/components/schemas/Health') {
    throw 'Health endpoint must return the shared Health schema.'
}

foreach ($authPath in @('/api/v1/auth/register', '/api/v1/auth/login', '/api/v1/auth/logout', '/api/v1/auth/password-reset/complete', '/api/v1/admin/password-reset-links')) {
    $operation = $openApi.paths.$authPath.post
    if ($null -eq $operation) {
        throw "Auth contract must define POST $authPath."
    }
}

if ($null -eq $openApi.paths.'/api/v1/auth/session'.get) {
    throw 'Auth contract must define GET /api/v1/auth/session.'
}

if ($null -eq $openApi.paths.'/api/v1/me'.get -or $null -eq $openApi.paths.'/api/v1/me'.patch) {
    throw 'Profile contract must define GET and PATCH /api/v1/me.'
}

if ($openApi.paths.'/api/v1/me'.get.responses.'200'.content.'application/json'.schema.'$ref' -ne '#/components/schemas/OwnProfile' -or
    $openApi.paths.'/api/v1/me'.patch.requestBody.content.'application/json'.schema.'$ref' -ne '#/components/schemas/OwnProfileUpdateRequest') {
    throw 'Profile operations must reference the shared own-profile schemas.'
}

if ($null -eq $openApi.components.schemas.OwnProfile.properties.login.readOnly -or
    $null -eq $openApi.components.schemas.OwnProfileUpdateRequest.properties.display_name) {
    throw 'Profile contract must keep login read-only and allow display_name updates.'
}

if ($openApi.paths.'/api/v1/me/password'.post.operationId -ne 'changePassword' -or
    $openApi.paths.'/api/v1/me/password'.post.requestBody.content.'application/json'.schema.'$ref' -ne '#/components/schemas/OwnPasswordChangeRequest') {
    throw 'Profile contract must define the current-password-confirmed changePassword operation.'
}

if ($openApi.components.schemas.OwnPasswordChangeRequest.additionalProperties -ne $false -or
    $openApi.components.schemas.OwnPasswordChangeRequest.required -notcontains 'current_password' -or
    $openApi.components.schemas.OwnPasswordChangeRequest.required -notcontains 'new_password') {
    throw 'Password change contract must require both passwords and reject unknown fields.'
}

if ($openApi.paths.'/api/v1/me/avatar'.put.operationId -ne 'uploadAvatar' -or
    $openApi.paths.'/api/v1/me/avatar'.delete.operationId -ne 'deleteAvatar' -or
    $openApi.paths.'/api/v1/members'.get.operationId -ne 'listMembers' -or
    $openApi.paths.'/api/v1/members/{userID}'.get.operationId -ne 'getMember' -or
    $openApi.paths.'/api/v1/members/{userID}/avatar'.get.operationId -ne 'getMemberAvatar') {
    throw 'Profile contract must define private avatar and authenticated member operations.'
}

if ($openApi.paths.'/api/v1/admin/accounts'.get.operationId -ne 'listAdminAccounts' -or
    $openApi.paths.'/api/v1/admin/audit'.get.operationId -ne 'listAudit') {
    throw 'Administration contract must define account listing and audit summary operations.'
}

foreach ($schemaName in @('Member', 'MemberList', 'AdminAccount', 'AdminAccountList', 'AuditEvent', 'AuditEventList')) {
    if ($null -eq $openApi.components.schemas.$schemaName) {
        throw "Profile and administration contract must define $schemaName."
    }
}

if ($null -eq $openApi.components.schemas.OwnProfile.properties.avatar_url -or
    $openApi.components.schemas.AuditEvent.properties.metadata -or
    $openApi.components.schemas.AdminAccount.properties.password_hash -or
    $openApi.components.schemas.AdminAccount.properties.session) {
    throw 'Profile and admin schemas must not expose storage keys, audit metadata or credentials.'
}

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
if ($null -eq $openApi.components.schemas.Channel.properties.mention_count -or
    $null -eq $openApi.components.schemas.DirectMessageListItem.properties.mention_count) {
    throw 'Navigation contract must define caller-local mention counts for TEXT and DM.'
}

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

if ($null -eq $openApi.paths.'/api/v1/voice/channels/{channelID}/leases'.post) {
    throw 'Voice contract must define POST /api/v1/voice/channels/{channelID}/leases.'
}

if ($null -eq $openApi.paths.'/api/v1/voice/leases/{leaseID}'.delete) {
    throw 'Voice contract must define DELETE /api/v1/voice/leases/{leaseID}.'
}

if ($null -eq $openApi.paths.'/api/v1/voice/leases/{leaseID}/credential'.post) {
    throw 'Media contract must define POST /api/v1/voice/leases/{leaseID}/credential.'
}

if ($null -eq $openApi.paths.'/api/v1/admin/accounts/{accountID}/voice-kick'.post) {
    throw 'Voice contract must define POST /api/v1/admin/accounts/{accountID}/voice-kick.'
}

foreach ($operation in @(
    $openApi.paths.'/api/v1/admin/accounts/{accountID}/voice-kick'.post,
    $openApi.paths.'/api/v1/admin/voice-channels/{channelID}/close-admission'.post
)) {
    if ($operation.description -notmatch 'durable SFU revocation') {
        throw 'Voice revocation operations must describe the durable SFU-revocation outcome.'
    }
}

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

Write-Output 'Contracts OK.'
