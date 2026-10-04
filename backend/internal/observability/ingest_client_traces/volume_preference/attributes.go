package volumepreference

import commonpb "go.opentelemetry.io/proto/otlp/common/v1"

// Keep only a closed outcome and the platform validated by the relay.
func Clean(input []*commonpb.KeyValue, platform string) []*commonpb.KeyValue {
	pair := func(k, v string) *commonpb.KeyValue {
		return &commonpb.KeyValue{Key: k, Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: v}}}
	}
	result := []*commonpb.KeyValue{pair("client.platform", platform)}
	for _, attribute := range input {
		if attribute == nil || attribute.Value == nil || attribute.Key != "volume_preference_apply" {
			continue
		}
		value := attribute.Value.GetStringValue()
		if value == "success" || value == "fallback" || value == "error" {
			return append(result, pair("volume_preference_apply", value))
		}
	}
	return result
}
