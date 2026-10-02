if ($null -eq $openApi.paths.'/api/v1/voice/channels/{channelID}/leases'.post) {
    throw 'Voice contract must define POST /api/v1/voice/channels/{channelID}/leases.'
}

$voiceRosterEvents = $openApi.paths.'/api/v1/voice/rosters/events'.get
if ($null -eq $voiceRosterEvents -or
    $voiceRosterEvents.operationId -ne 'watchConnectedVoiceParticipants' -or
    $voiceRosterEvents.responses.'200'.content.'text/event-stream'.schema.type -ne 'string' -or
    $null -eq $voiceRosterEvents.responses.'401' -or
    $voiceRosterEvents.responses.'503'.content.'text/plain'.schema.type -ne 'string' -or
    $voiceRosterEvents.responses.'500'.content.'text/plain'.schema.type -ne 'string') {
    throw 'Voice contract must define the authenticated SSE roster stream and its 401/500/503 outcomes.'
}

$voiceParticipant = $openApi.components.schemas.VoiceParticipant
if ($voiceParticipant.required -notcontains 'microphone_muted' -or
    $voiceParticipant.properties.microphone_muted.type -ne 'boolean') {
    throw 'Voice participant contract must expose the server-observed microphone_muted state.'
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
