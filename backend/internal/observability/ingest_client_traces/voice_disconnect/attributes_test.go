package voicedisconnect

import (
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	"testing"
)

func pair(key, value string) *commonpb.KeyValue {
	return &commonpb.KeyValue{Key: key, Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: value}}}
}
func TestClosedTerminationOutcome(t *testing.T) {
	input := []*commonpb.KeyValue{pair("voice.disconnect.reason", "kick"), pair("voice.disconnect.source", "server"), pair("lease_id", "private"), pair("username", "private"), pair("message", "private"), pair("client.platform", "spoof")}
	clean := Clean(input, "windows")
	if len(clean) != 4 || clean[0].Value.GetStringValue() != "windows" || !clean[3].Value.GetBoolValue() {
		t.Fatalf("unsafe attrs: %v", clean)
	}
	input[0] = pair("voice.disconnect.reason", "banned")
	if Clean(input, "web")[3].Value.GetBoolValue() {
		t.Fatal("banned reconnect allowed")
	}
	input[0] = pair("voice.disconnect.reason", "private-free-text")
	if len(Clean(input, "web")) != 1 {
		t.Fatal("unknown reason survived")
	}
	input[0] = pair("voice.disconnect.reason", "kick")
	input[1] = pair("voice.disconnect.source", "transport")
	if len(Clean(input, "web")) != 1 {
		t.Fatal("inconsistent source survived")
	}
}
