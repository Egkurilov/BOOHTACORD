foreach ($path in @('/api/v1/channels/{channelID}/message-delivery/{clientMessageID}', '/api/v1/direct-messages/{directMessageID}/message-delivery/{clientMessageID}')) {
    $operation = $openApi.paths.$path.get
    if (-not $operation) { throw "Missing caller delivery lookup: $path" }
    foreach ($status in @('400','401','404','500')) {
        if (-not $operation.responses.$status) { throw "Missing delivery error $status in $path" }
    }
    if ($operation.responses.'200'.content.'application/json'.schema.'$ref' -ne '#/components/schemas/OwnMessageDelivery') {
        throw 'Delivery response must use the private receipt schema.'
    }
}
$receipt = $openApi.components.schemas.OwnMessageDelivery
if ($receipt.additionalProperties -ne $false -or @($receipt.properties.PSObject.Properties).Count -ne 2) {
    throw 'Delivery receipt must contain only caller and message handles.'
}
