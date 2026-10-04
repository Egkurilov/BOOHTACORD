package ingestclienttraces

import (
	"bytes"
	"testing"
	"time"

	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
)

func TestAudioInputOutcomeStripsDeviceDetailsAndUnboundedAttributes(t *testing.T) {
	for _, platform := range []string{"web", "android", "ios", "windows", "macos"} {
		for _, phase := range []string{"prejoin", "active", "reconnect"} {
			for _, result := range []string{"success", "fallback", "error"} {
				now := uint64(time.Now().UnixNano())
				span := &tracepb.Span{TraceId: bytes.Repeat([]byte{1}, 16), SpanId: bytes.Repeat([]byte{2}, 8), Name: "audio.input.switch", StartTimeUnixNano: now - 1000, EndTimeUnixNano: now}
				attribute := func(key, value string) *commonpb.KeyValue {
					return &commonpb.KeyValue{Key: key, Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: value}}}
				}
				span.Attributes = []*commonpb.KeyValue{attribute("platform", "spoofed-model"), attribute("phase", phase), attribute("result", result), attribute("device.id", "private-device"), attribute("device.label", "private-label"), attribute("error", "private-details")}
				output, ok := sanitize(traceRequest(span), platform)
				if !ok {
					t.Fatal("bounded input switch rejected")
				}
				attrs := output.ResourceSpans[0].ScopeSpans[0].Spans[0].Attributes
				if len(attrs) != 3 {
					t.Fatalf("attributes=%v", attrs)
				}
				got := map[string]string{}
				for _, attr := range attrs {
					got[attr.Key] = attr.Value.GetStringValue()
				}
				if got["platform"] != platform || got["phase"] != phase || got["result"] != result {
					t.Fatalf("attributes=%v", got)
				}
				span.Attributes = []*commonpb.KeyValue{attribute("phase", "private-device"), attribute("result", "private-label")}
				output, ok = sanitize(traceRequest(span), platform)
				if !ok || len(output.ResourceSpans[0].ScopeSpans[0].Spans[0].Attributes) != 1 {
					t.Fatal("unbounded switch attributes retained")
				}
			}
		}
	}
}
