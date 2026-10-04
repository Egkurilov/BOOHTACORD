package voiceaudio

import (
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	"testing"
)

func TestOnlyBoundedDiagnosticAttributesSurvive(t *testing.T) {
	pair := func(k, v string) *commonpb.KeyValue {
		return &commonpb.KeyValue{Key: k, Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: v}}}
	}
	attrs := Clean([]*commonpb.KeyValue{pair("voice.audio.profile", "speech-64-v1"), pair("direction", "sender"), pair("codec", "opus"), pair("bitrate_kbps", "64"), pair("audio.level", "0.51"), pair("device.label", "private"), pair("client.platform", "spoof"), pair("channels", "999"), pair("jitter_ms", "1.2345")}, "windows")
	got := map[string]string{}
	for _, a := range attrs {
		got[a.Key] = a.Value.GetStringValue()
	}
	if len(got) != 5 || got["client.platform"] != "windows" || got["bitrate_kbps"] != "64" {
		t.Fatalf("attributes=%v", got)
	}
	if len(Clean([]*commonpb.KeyValue{pair("voice.audio.profile", "private-profile"), pair("concealed_samples", "NaN")}, "web")) != 1 {
		t.Fatal("unbounded attributes retained")
	}
}
