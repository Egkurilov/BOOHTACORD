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
