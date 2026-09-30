package ingestclienttraces

import (
	"bytes"
	"testing"
	"time"

	collectortrace "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
)

func TestSanitizeKeepsOnlyBoundedClientEvents(t *testing.T) {
	now := uint64(time.Now().UnixNano())
	span := &tracepb.Span{
		TraceId: bytes.Repeat([]byte{1}, 16), SpanId: bytes.Repeat([]byte{2}, 8), Name: "voice.join",
		StartTimeUnixNano: now - 1000000, EndTimeUnixNano: now,
		Events: []*tracepb.Span_Event{
			{TimeUnixNano: now - 900000, Name: "app.client.voice.join.started"},
			{TimeUnixNano: now - 800000, Name: "app.client.voice.join.completed", Attributes: []*commonpb.KeyValue{{Key: "message", Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "private-message"}}}}},
			{TimeUnixNano: now - 700000, Name: "private-message"},
			{TimeUnixNano: now + 1000000, Name: "app.client.voice.join.failed"},
		},
	}
	input := traceRequest(span)
	output, ok := sanitize(input, "web")
	if !ok {
		t.Fatal("safe span rejected")
	}
	events := output.ResourceSpans[0].ScopeSpans[0].Spans[0].Events
	if len(events) != 2 {
		t.Fatalf("events=%+v", events)
	}
	for _, event := range events {
		if len(event.Attributes) != 0 || event.Name == "private-message" {
			t.Fatalf("unsafe event: %+v", event)
		}
	}
}

func traceRequest(span *tracepb.Span) *collectortrace.ExportTraceServiceRequest {
	return &collectortrace.ExportTraceServiceRequest{ResourceSpans: []*tracepb.ResourceSpans{{ScopeSpans: []*tracepb.ScopeSpans{{Spans: []*tracepb.Span{span}}}}}}
}
