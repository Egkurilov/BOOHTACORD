$flow = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '../../../contracts/telemetry-flow-v1.json') | ConvertFrom-Json
if ($flow.version -ne 1 -or $flow.limits.spans -ne 32 -or $flow.limits.durationSeconds -ne 120 -or $flow.limits.queue -ne 128) {
    throw 'Telemetry flow contract must preserve bounded short-action budgets.'
}
foreach ($field in @('session.id', 'app.visit.id', 'app.flow.id', 'app.flow.stage', 'app.flow.record', 'app.flow.outcome', 'app.provenance')) {
    if ($null -eq $flow.fields.$field) { throw "Telemetry contract is missing $field." }
}
if ($realtime.required -contains 'telemetry' -or $realtime.properties.telemetry.additionalProperties -ne $false) {
    throw 'Realtime causal metadata must stay optional and bounded.'
}
if ($realtime.properties.telemetry.properties.reference.maxLength -ne 512) {
    throw 'Realtime causal reference must be bounded to 512 characters.'
}
if ($openApi.paths.'/api/v1/telemetry/traces'.post.responses.'202'.headers.'X-Telemetry-Rejected'.schema.maximum -ne 32) {
    throw 'Relay must document bounded partial rejection counts.'
}
