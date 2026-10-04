package ingestclienttraces

import (
	"bytes"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
	"testing"
	"time"
)

func TestVolumeOutcomeRelay(t *testing.T) {
	now := uint64(time.Now().UnixNano())
	span := &tracepb.Span{TraceId: bytes.Repeat([]byte{1}, 16), SpanId: bytes.Repeat([]byte{2}, 8), Name: "voice.volume.preference", StartTimeUnixNano: now - 1000, EndTimeUnixNano: now}
	pair := func(k, v string) *commonpb.KeyValue {
		return &commonpb.KeyValue{Key: k, Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: v}}}
	}
	span.Attributes = []*commonpb.KeyValue{pair("volume_preference_apply", "fallback"), pair("participant_id", "private"), pair("volume", "175"), pair("client.platform", "spoof")}
	for _, platform := range []string{"web", "windows", "android", "ios"} {
		output, ok := sanitize(traceRequest(span), platform)
		if !ok {
			t.Fatal("outcome rejected")
		}
		clean := output.ResourceSpans[0].ScopeSpans[0].Spans[0].Attributes
		if len(clean) != 2 || clean[0].Value.GetStringValue() != platform || clean[1].Value.GetStringValue() != "fallback" {
			t.Fatal("unsafe attributes")
		}
	}
}
