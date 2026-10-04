package volumepreference

import (
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	"testing"
)

func attr(key, value string) *commonpb.KeyValue {
	return &commonpb.KeyValue{Key: key, Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: value}}}
}
func TestClosedOutcomesAndPrivacy(t *testing.T) {
	for _, outcome := range []string{"success", "fallback", "error"} {
		clean := Clean([]*commonpb.KeyValue{attr("volume_preference_apply", outcome), attr("client.platform", "spoof"), attr("participant_id", "secret"), attr("volume", "175"), attr("name", "secret")}, "windows")
		if len(clean) != 2 || clean[0].Value.GetStringValue() != "windows" || clean[1].Value.GetStringValue() != outcome {
			t.Fatalf("unexpected closed attributes: %v", clean)
		}
	}
	clean := Clean([]*commonpb.KeyValue{nil, attr("volume_preference_apply", "175"), attr("remote_account_id", "secret")}, "web")
	if len(clean) != 1 || clean[0].Key != "client.platform" {
		t.Fatal("untrusted value survived")
	}
}
