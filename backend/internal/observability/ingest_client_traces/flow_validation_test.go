package ingestclienttraces

import (
	"bytes"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
	"strings"
	"testing"
	"time"
	cause "voice-platform/backend/internal/observability/causal_reference"
)

func TestVersionedFlowRequiresDeclaredStage(t *testing.T) {
	span := flowSpan()
	attrs := span.Attributes[:0]
	for _, attr := range span.Attributes {
		if attr.Key != "app.flow.stage" {
			attrs = append(attrs, attr)
		}
	}
	span.Attributes = attrs
	_, result := sanitizeBatch(flowBatch(span), "web", "11111111111111111111111111111111", "verified")
	if result.Fatal || result.Rejected != 1 || result.Accepted != 0 {
		t.Fatalf("missing stage must be partially rejected: %+v", result)
	}
}

func TestRelayRejectsOverlongSpanNamesAndAttributeStrings(t *testing.T) {
	cases := []func(*tracepb.Span){
		func(span *tracepb.Span) { span.Name = strings.Repeat("n", 65) },
		func(span *tracepb.Span) {
			span.Attributes = append(span.Attributes, flowAttr(strings.Repeat("k", 129), "v"))
		},
		func(span *tracepb.Span) {
			span.Attributes = append(span.Attributes, flowAttr("app.test.value", strings.Repeat("v", 513)))
		},
	}
	for i, mutate := range cases {
		span := flowSpan()
		mutate(span)
		if _, result := sanitizeBatch(flowBatch(span), "web", "11111111111111111111111111111111", "verified"); !result.Fatal || result.Reason != "malformed" {
			t.Errorf("case %d accepted overlong data: %+v", i, result)
		}
	}
}

func TestDuplicateRecordsAndNestedBudgetsRejectWholeBatch(t *testing.T) {
	first := flowSpan()
	if _, r := sanitizeBatch(flowBatch(first, first), "web", "1"+string(bytes.Repeat([]byte("1"), 31)), "verified"); !r.Fatal {
		t.Fatal("duplicate span accepted")
	}
	first.Events = []*tracepb.Span_Event{{Attributes: make([]*commonpb.KeyValue, 33)}}
	if _, r := sanitizeBatch(flowBatch(first), "web", "11111111111111111111111111111111", "verified"); !r.Fatal {
		t.Fatal("nested attribute budget ignored")
	}
}

func TestForeignAudienceCannotExportTrustedCausalLink(t *testing.T) {
	original := flowSpan()
	c := cause.Cause{TraceID: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", SpanID: "bbbbbbbbbbbbbbbb", Version: 1}
	tid, sid := c.IDs()
	original.Links = []*tracepb.Span_Link{{TraceId: tid, SpanId: sid, Attributes: []*commonpb.KeyValue{flowAttr("app.causal.ref", cause.Sign("synthetic", "recipient-a", c, time.Now()))}}}
	input := flowBatch(original)
	output, r := sanitizeBatch(input, "web", "11111111111111111111111111111111", "recipient-b")
	if r.Accepted != 1 {
		t.Fatal(r)
	}
	verifiedLinks(input, output, "synthetic", "recipient-b")
	if len(output.ResourceSpans[0].ScopeSpans[0].Spans[0].Links) != 0 {
		t.Fatal("foreign audience link accepted")
	}
	verifiedLinks(input, output, "synthetic", "recipient-a")
	if len(output.ResourceSpans[0].ScopeSpans[0].Spans[0].Links) != 1 {
		t.Fatal("authorized audience link lost")
	}
}
