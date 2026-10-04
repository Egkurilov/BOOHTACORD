package ingestclienttraces

import (
	"bytes"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
	"testing"
	"time"
)

func TestVoiceAudioSpanUsesSanitizedPlatformAndDropsSensitiveData(t *testing.T) {
	now := uint64(time.Now().UnixNano())
	span := &tracepb.Span{TraceId: bytes.Repeat([]byte{1}, 16), SpanId: bytes.Repeat([]byte{2}, 8), Name: "voice.audio.sample", StartTimeUnixNano: now - 1000, EndTimeUnixNano: now}
	attr := func(k, v string) *commonpb.KeyValue {
		return &commonpb.KeyValue{Key: k, Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: v}}}
	}
	span.Attributes = []*commonpb.KeyValue{attr("client.platform", "spoofed"), attr("voice.audio.profile", "speech-96-v1"), attr("audioLevel", "0.33333"), attr("device.label", "private"), attr("bitrate_kbps", "96")}
	for _, platform := range []string{"web", "windows", "android", "ios", "macos"} {
		output, ok := sanitize(traceRequest(span), platform)
		if !ok {
			t.Fatal("voice sample rejected")
		}
		attributes := output.ResourceSpans[0].ScopeSpans[0].Spans[0].Attributes
		if len(attributes) != 3 || attributes[0].Value.GetStringValue() != platform {
			t.Fatalf("attrs=%v", attributes)
		}
	}
}
