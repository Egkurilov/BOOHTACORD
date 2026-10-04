package voicedisconnect

import commonpb "go.opentelemetry.io/proto/otlp/common/v1"

func Clean(input []*commonpb.KeyValue, platform string) []*commonpb.KeyValue {
	pair := func(k, v string) *commonpb.KeyValue {
		return &commonpb.KeyValue{Key: k, Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: v}}}
	}
	output := []*commonpb.KeyValue{pair("client.platform", platform)}
	reason, source := "", ""
	for _, attr := range input {
		if attr == nil || attr.Value == nil {
			continue
		}
		switch attr.Key {
		case "voice.disconnect.reason":
			reason = attr.Value.GetStringValue()
		case "voice.disconnect.source":
			source = attr.Value.GetStringValue()
		}
	}
	allowed := map[string]bool{"kick": true, "channel_closed": false, "banned": false, "session_revoked": false, "logout": false, "transfer": true, "voluntary_leave": true, "transport": true}
	reconnect, valid := allowed[reason]
	if !valid || !(source == "server" && reason != "transport" || source == "local" && reason == "voluntary_leave" || source == "transport" && reason == "transport") {
		return output
	}
	return append(output, pair("voice.disconnect.reason", reason), pair("voice.disconnect.source", source), &commonpb.KeyValue{Key: "voice.reconnect_allowed", Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_BoolValue{BoolValue: reconnect}}})
}
