package ingestclienttraces

import (
	"bytes"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
	"testing"
	"time"
)

func TestClientCannotForgeGuildLifecycle(t *testing.T) {
	now := uint64(time.Now().UnixNano())
	span := &tracepb.Span{TraceId: bytes.Repeat([]byte{1}, 16), SpanId: bytes.Repeat([]byte{2}, 8), Name: "api.request", StartTimeUnixNano: now - 1000, EndTimeUnixNano: now}
	for _, key := range []string{"user.id", "user.name", "session.id", "welcome.outcome", "guild.settings.revision", "channel.id", "message.id"} {
		span.Attributes = append(span.Attributes, &commonpb.KeyValue{Key: key, Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: "forged"}}})
	}
	span.Events = []*tracepb.Span_Event{{Name: "app.guild.name.updated", TimeUnixNano: now}, {Name: "app.registration.welcome.published", TimeUnixNano: now}}
	clean, ok := sanitize(traceRequest(span), "web")
	if !ok {
		t.Fatal("safe client operation rejected")
	}
	got := clean.ResourceSpans[0].ScopeSpans[0].Spans[0]
	if len(got.Attributes) != 0 || len(got.Events) != 0 || got.Kind == tracepb.Span_SPAN_KIND_SERVER {
		t.Fatal("server identity or lifecycle accepted from client")
	}
	for _, name := range []string{"guild.settings.update", "registration.welcome"} {
		span.Name = name
		if _, ok := sanitize(traceRequest(span), "web"); ok {
			t.Fatal("server span accepted from client")
		}
	}
}
