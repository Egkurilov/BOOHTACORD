package ingestclienttraces

import (
	"bytes"
	collectortrace "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
	"testing"
	"time"
)

func flowAttr(key, value string) *commonpb.KeyValue {
	return &commonpb.KeyValue{Key: key, Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_StringValue{StringValue: value}}}
}
func flowSpan() *tracepb.Span {
	now := uint64(time.Now().UnixNano())
	return &tracepb.Span{TraceId: bytes.Repeat([]byte{1}, 16), SpanId: bytes.Repeat([]byte{2}, 8), Name: "screen.view",
		StartTimeUnixNano: now - 1000000, EndTimeUnixNano: now, Attributes: []*commonpb.KeyValue{
			{Key: "app.schema.version", Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_IntValue{IntValue: 1}}},
			flowAttr("session.id", "11111111111111111111111111111111"), flowAttr("app.visit.id", "22222222222222222222222222222222"),
			flowAttr("app.flow.id", "33333333333333333333333333333333"), flowAttr("app.flow.name", "screen.view"),
			flowAttr("app.flow.record", "terminal"), flowAttr("app.flow.outcome", "timeout"), flowAttr("app.flow.stage", "first_frame"),
			{Key: "app.flow.attempt", Value: &commonpb.AnyValue{Value: &commonpb.AnyValue_IntValue{IntValue: 1}}},
			flowAttr("user.id", "spoof"), flowAttr("dm.body", "secret")}}
}
func flowBatch(spans ...*tracepb.Span) *collectortrace.ExportTraceServiceRequest {
	return &collectortrace.ExportTraceServiceRequest{ResourceSpans: []*tracepb.ResourceSpans{{ScopeSpans: []*tracepb.ScopeSpans{{Spans: spans}}}}}
}
func TestFlowPartialAcceptanceAndSameSessionLinks(t *testing.T) {
	first := flowSpan()
	second := flowSpan()
	second.SpanId = bytes.Repeat([]byte{3}, 8)
	first.Links = []*tracepb.Span_Link{{TraceId: second.TraceId, SpanId: second.SpanId}, {TraceId: bytes.Repeat([]byte{9}, 16), SpanId: second.SpanId}}
	unknown := flowSpan()
	unknown.Name = "unknown"
	unknown.SpanId = bytes.Repeat([]byte{4}, 8)
	output, result := sanitizeBatch(flowBatch(first, unknown, second), "web", "11111111111111111111111111111111", "verified")
	if result.Fatal || result.Rejected != 1 || result.Accepted != 2 {
		t.Fatalf("%+v", result)
	}
	got := output.ResourceSpans[0].ScopeSpans[0].Spans[0]
	if got.Kind != tracepb.Span_SPAN_KIND_INTERNAL || len(got.Links) != 1 {
		t.Fatalf("%+v", got)
	}
	attrs := map[string]string{}
	for _, a := range got.Attributes {
		attrs[a.Key] = a.Value.GetStringValue()
	}
	if attrs["user.id"] != "verified" || attrs["dm.body"] != "" || attrs["app.flow.stage"] != "first_frame" || attrs["app.provenance"] != "client_observed" {
		t.Fatal(attrs)
	}
}
func TestStaleBatchCannotBecomeAnotherAccountsTelemetry(t *testing.T) {
	_, result := sanitizeBatch(flowBatch(flowSpan()), "web", "44444444444444444444444444444444", "other")
	if !result.Fatal || result.Reason != "session_mismatch" {
		t.Fatal(result)
	}
}
func TestOversizeAndMalformedBatchRejectWhole(t *testing.T) {
	spans := make([]*tracepb.Span, 33)
	for i := range spans {
		spans[i] = flowSpan()
	}
	_, r := sanitizeBatch(flowBatch(spans...), "web", "", "")
	if !r.Fatal {
		t.Fatal("oversize accepted")
	}
	bad := flowSpan()
	bad.TraceId = make([]byte, 16)
	_, r = sanitizeBatch(flowBatch(flowSpan(), bad), "web", "11111111111111111111111111111111", "verified")
	if !r.Fatal {
		t.Fatal("zero trace accepted")
	}
}
