package ingestclienttraces

import (
	"bytes"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
	"testing"
	"time"
)

func TestDisconnectRelayAcceptsSemanticOutcomeAndDropsPrivateValues(t *testing.T) {
	now := uint64(time.Now().UnixNano())
	span := &tracepb.Span{TraceId: bytes.Repeat([]byte{1}, 16), SpanId: bytes.Repeat([]byte{2}, 8), Name: "voice.disconnect", StartTimeUnixNano: now - 1000, EndTimeUnixNano: now}
	pair := func(k, v string) *commonpb.KeyValue {
		return &commonpb.KeyValue{Key: k, Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: v}}}
	}
	span.Attributes = []*commonpb.KeyValue{pair("voice.disconnect.reason", "kick"), pair("voice.disconnect.source", "server"), pair("lease_id", "private"), pair("username", "private")}
	for _, platform := range []string{"web", "android", "ios", "windows"} {
		output, ok := sanitize(traceRequest(span), platform)
		if !ok {
			t.Fatal("disconnect rejected")
		}
		clean := output.ResourceSpans[0].ScopeSpans[0].Spans[0].Attributes
		if len(clean) != 4 || clean[0].Value.GetStringValue() != platform || !clean[3].Value.GetBoolValue() {
			t.Fatal("unsafe semantic attrs")
		}
	}
}
func TestInterruptedReconnectEventSurvivesWithoutAttributes(t *testing.T) {
	span := &tracepb.Span{Name: "voice.reconnect", StartTimeUnixNano: 1, EndTimeUnixNano: 10, Events: []*tracepb.Span_Event{{Name: "app.client.voice.reconnect.interrupted", TimeUnixNano: 5, Attributes: []*commonpb.KeyValue{{Key: "lease_id"}}}}}
	clean := safeClientEvents(span)
	if len(clean) != 1 || len(clean[0].Attributes) != 0 {
		t.Fatal("unsafe interrupted event")
	}
}
