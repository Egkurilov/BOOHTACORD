$permissionNames = @('channel.text.create','channel.text.delete','channel.voice.create','channel.voice.delete','category.create','category.delete')
$permissionSchema = $openApi.components.schemas.PermissionValues
if ($permissionSchema.additionalProperties -ne $false -or $permissionSchema.required.Count -ne 6) {
    throw 'PermissionValues must be an exact six-key map.'
}
foreach ($name in $permissionNames) {
    if ($permissionSchema.required -notcontains $name -or $permissionSchema.properties.$name.type -ne 'boolean') {
        throw "PermissionValues is missing $name."
    }
}

$operations = @{
    '/api/v1/auth/permissions' = @('get','getEffectivePermissions')
    '/api/v1/admin/roles' = @('get','listRolePolicies')
    '/api/v1/admin/roles/{role}/permissions' = @('put','updateMemberRolePolicy')
    '/api/v1/categories' = @('post','createMemberCategory')
    '/api/v1/categories/{categoryID}/channels' = @('post','createMemberChannel')
    '/api/v1/categories/{categoryID}' = @('delete','deleteMemberCategory')
    '/api/v1/channels/{channelID}' = @('delete','archiveMemberTextChannel')
    '/api/v1/voice-channels/{channelID}/close-admission' = @('post','closeMemberVoiceChannel')
    '/api/v1/topology-commands/{clientRequestID}' = @('get','getTopologyCommand')
}
foreach ($entry in $operations.GetEnumerator()) {
    $operation = $openApi.paths.($entry.Key).($entry.Value[0])
    if ($null -eq $operation -or $operation.operationId -ne $entry.Value[1]) {
        throw "Role topology contract is missing $($entry.Key)."
    }
}

$kinds = $realtime.properties.kind.enum
foreach ($kind in @('role.permissions.updated','auth.permissions.invalidated')) {
    if ($kinds -notcontains $kind) { throw "Realtime contract is missing $kind." }
}
