package ingestclienttraces

import (
	"bytes"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	tracepb "go.opentelemetry.io/proto/otlp/trace/v1"
	"testing"
	"time"
	cause "voice-platform/backend/internal/observability/causal_reference"
)

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
